import Foundation
import SwiftData
import Testing
@testable import YatTatTa

@MainActor struct TodayRecordsTests {
    private let container = try! ModelContainer(
        for: SquatRecord.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    private let defaults = UserDefaults(suiteName: "TodayRecordsTests-\(UUID())")!
    /// 2026-10-06 の20時（JST）。記録日は 20261006
    private let now = Date(timeIntervalSince1970: 1_791_284_400)

    /// 昨日までに days 日続いた記録を入れてから作る
    private func makeModel(pastDays days: Int = 0) -> AppModel {
        let today = RecordDay(now)
        for i in 1...max(days, 1) where days > 0 {
            container.mainContext.insert(SquatRecord(startedAt: now, day: today.adding(days: -i), reps: 10))
        }
        let model = AppModel(context: container.mainContext, defaults: defaults, now: { [now] in now })
        model.draw = { 1 }
        model.targetReps = 5
        return model
    }

    /// 隊を起こして叩き切り、1件作る。start は叩き始めの時刻（touch.timestamp と同じ時計）
    private func mash(_ model: AppModel, from start: TimeInterval) {
        model.wake()
        for i in 0..<5 { _ = model.tap(at: start + Double(i) * 0.2) }
    }

    @Test func 今日の記録だけが並ぶ() {
        let model = makeModel(pastDays: 3)
        mash(model, from: 0)
        mash(model, from: 10)
        #expect(model.todayRecords.count == 2)
        #expect(model.todayRecords.allSatisfy { $0.day == RecordDay(now).value })
    }

    @Test func 最後の1件を消すと今日はまだに戻りDTも戻る() {
        let model = makeModel(pastDays: 29)
        mash(model, from: 0)
        #expect(model.ledger.streak.current == 30)
        #expect(model.ledger.dopaTotal == 295)

        model.delete(model.todayRecords[0])
        #expect(model.todayRecords.isEmpty)
        #expect(!model.ledger.streak.doneToday)
        #expect(model.ledger.streak.current == 29)
        #expect(model.ledger.streak.nextCount == 30)
        #expect(model.ledger.dopaTotal == 290)
        #expect(model.breakNotice == nil)
    }

    @Test func 七日目の記録を消すとその日の休み券も消える() {
        let model = makeModel(pastDays: 6)
        #expect(model.ledger.streak.restPasses == 0)
        mash(model, from: 0)
        #expect(model.ledger.streak.restPasses == 1)

        model.delete(model.todayRecords[0])
        #expect(model.ledger.streak.restPasses == 0)
    }

    @Test func 一件だけ消すと残りはそのまま() {
        let model = makeModel()
        mash(model, from: 0)
        mash(model, from: 10)
        let kept = model.todayRecords[1].id
        model.delete(model.todayRecords[0])
        #expect(model.todayRecords.map(\.id) == [kept])
        #expect(model.ledger.dopaTotal == 5)
        #expect(model.ledger.streak.doneToday)
    }

    @Test func 昨日の記録は消せない() {
        let model = makeModel(pastDays: 1)
        let yesterday = try! container.mainContext.fetch(FetchDescriptor<SquatRecord>()).first!
        model.delete(yesterday)
        #expect(model.ledger.dopaTotal == 10)
    }

    @Test func 叩いている最中は消せない() {
        let model = makeModel()
        mash(model, from: 0)
        model.wake()
        _ = model.tap(at: 10)
        #expect(model.session.isOpen)
        model.delete(model.todayRecords[0])
        #expect(model.todayRecords.count == 1)
    }
}
