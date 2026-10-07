import FirebaseFirestore
import Foundation
import Testing
@testable import YatTatTa

/// ほかの端末の記録やサーバーの答えが、あとから届くとき
@MainActor struct RecordSyncTests {
    private let defaults = UserDefaults(suiteName: "RecordSyncTests-\(UUID())")!
    /// 2026-10-06 の20時（JST）。記録日は 20261006
    private let now = Date(timeIntervalSince1970: 1_791_284_400)
    private var today: RecordDay { RecordDay(now) }

    private func makeModel(_ store: MemoryRecordStore) -> AppModel {
        let model = AppModel(store: store, defaults: defaults, now: { [now] in now })
        model.draw = { 1 }
        model.targetReps = 5
        return model
    }

    @Test func 叩いている最中に届いた記録は閉じるまでDTに入らない() {
        let store = MemoryRecordStore()
        let model = makeModel(store)
        model.wake()
        for i in 0..<3 { _ = model.tap(at: Double(i) * 0.2) }

        store.receive([SquatRecord(startedAt: now, day: today.adding(days: -1), reps: 995)])
        #expect(model.ledger.dopaTotal == 0)
        #expect(model.dopaTotal == 3)
        // 届いた分で 1,000 をまたいだことにしない
        _ = model.tap(at: 0.6)
        #expect(model.session.milestones.isEmpty)

        _ = model.tap(at: 0.8)
        #expect(model.ledger.dopaTotal == 1_000)
        #expect(model.ledger.streak.current == 2)
    }

    @Test func 届いた記録で今日の記録と連続記録が直る() {
        let store = MemoryRecordStore()
        let model = makeModel(store)
        #expect(!model.ledger.streak.doneToday)

        let other = SquatRecord(startedAt: now, day: today, reps: 20)
        store.receive([SquatRecord(startedAt: now, day: today.adding(days: -1), reps: 20), other])
        #expect(model.ledger.streak.doneToday)
        #expect(model.ledger.streak.current == 2)
        #expect(model.todayRecords.map(\.id) == [other.id])

        store.receive(removing: [other.id])
        #expect(!model.ledger.streak.doneToday)
        #expect(model.todayRecords.isEmpty)
    }

    @Test func サーバーの答えが返るまでチュートリアルを出さず記録が届いたら出さない() {
        let store = MemoryRecordStore(synced: false)
        let model = makeModel(store)
        model.finishSplash()
        #expect(model.tutorial == nil)

        store.receive([SquatRecord(startedAt: now, day: today.adding(days: -3), reps: 20)])
        #expect(model.tutorial == nil)
    }

    @Test func サーバーの答えが0件ならチュートリアルを出す() {
        let store = MemoryRecordStore(synced: false)
        let model = makeModel(store)
        model.finishSplash()
        store.receive()
        #expect(model.tutorial == .wake)
    }

    @Test func 文書から記録に戻せる() throws {
        let record = SquatRecord(startedAt: Date(timeIntervalSince1970: 1_791_284_400), day: today, reps: 20, bonusDopa: 7)
        var fields = FirestoreRecordStore.fields(of: record)
        #expect(fields["createdAt"] is FieldValue)
        fields["createdAt"] = Timestamp(date: now)
        let back = try #require(FirestoreRecordStore.record(id: record.id.uuidString, data: fields))
        #expect(back == record)
    }

    @Test func 形の合わない文書は読まない() {
        let fields: [String: Any] = ["startedAt": Timestamp(date: now), "day": 20261006]
        #expect(FirestoreRecordStore.record(id: UUID().uuidString, data: fields) == nil)
        #expect(FirestoreRecordStore.record(id: "not-a-uuid", data: ["startedAt": Timestamp(date: now), "day": 20261006, "reps": 5]) == nil)
    }
}
