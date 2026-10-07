import Foundation
import Testing
@testable import YatTatTa

@MainActor struct ShotSeedTests {
    private let now = Date(timeIntervalSince1970: 1_791_000_000)

    private func makeModel() -> AppModel {
        let store = MemoryRecordStore(records: ShotSeed.records(today: RecordDay(now)))
        return AppModel(store: store, defaults: ShotSeed.defaults(), now: { [now] in now })
    }

    @Test func 連続記録が続いていて今日はまだ叩いていない() {
        let model = makeModel()
        // 34日のうち1日は休み券で埋まり、連続日数には数えない
        #expect(model.ledger.streak.current == ShotSeed.days - 1)
        #expect(!model.ledger.streak.doneToday)
        #expect(model.todayRecords.isEmpty)
        #expect(model.breakNotice == nil)
        #expect(model.restPassNotice == nil)
        // 4枚めのホームで、今週のドパが前の7日より多く見える
        #expect(model.ledger.dopaPerWeek > model.ledger.previousWindow)
        #expect(model.targetReps == ShotSeed.target)
    }

    @Test func 何度作っても同じ記録になる() {
        let a = ShotSeed.records(today: RecordDay(now))
        let b = ShotSeed.records(today: RecordDay(now))
        #expect(a.map(\.startedAt) == b.map(\.startedAt))
        #expect(a.map(\.reps) == b.map(\.reps))
        #expect(a.map(\.bonusDopa) == b.map(\.bonusDopa))
    }

    @Test func 叩き始めはどれもその記録日の中にある() {
        let records = ShotSeed.records(today: RecordDay(now))
        #expect(records.allSatisfy { RecordDay($0.startedAt) == $0.recordDay })
        #expect(!records.contains { $0.recordDay == RecordDay(now).adding(days: -ShotSeed.skippedDay) })
    }
}
