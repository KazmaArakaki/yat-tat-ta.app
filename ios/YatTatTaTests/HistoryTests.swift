import Foundation
import Testing
@testable import YatTatTa

@MainActor struct HistoryTests {
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return c
    }()
    private let today = RecordDay(year: 2026, month: 10, day: 6)

    /// today から n 日前の記録日の、時刻 hour:minute（24 以上は翌日の早朝）に叩き始めた記録
    private func record(daysAgo n: Int, _ hour: Int, _ minute: Int = 0, reps: Int = 20, bonus: Int = 0) -> SquatRecord {
        let day = today.adding(days: -n)
        let date = calendar.date(from: DateComponents(
            year: day.value / 10000, month: day.value / 100 % 100, day: day.value % 100, hour: hour, minute: minute))!
        return SquatRecord(startedAt: date, day: RecordDay(date, calendar: calendar), reps: reps, bonusDopa: bonus)
    }

    private func history(_ records: [SquatRecord], rest: [RecordDay] = []) -> History {
        History(records: records, restPassDays: rest, today: today, calendar: calendar)
    }

    @Test func 記録がなければ空の7列() {
        let h = history([])
        #expect(h.days.count == 7)
        #expect(h.days.first?.day == today.adding(days: -6))
        #expect(h.days.last?.day == today)
        #expect(h.isEmpty)
        #expect(h.peak == 0)
    }

    @Test func 最初の列は最初の記録日と6日前の早いほう() {
        #expect(history([record(daysAgo: 2, 8)]).days.count == 7)
        let h = history([record(daysAgo: 20, 8)])
        #expect(h.days.count == 21)
        #expect(h.days.first?.day == today.adding(days: -20))
    }

    @Test func 日ごとのドパはフィーバーのドパも入る() {
        let h = history([record(daysAgo: 0, 8, reps: 20, bonus: 12), record(daysAgo: 0, 12, 41)])
        #expect(h.days.last?.dopa == 52)
        #expect(h.days.last?.entries.map(\.reps) == [20, 20])
        #expect(h.peak == 52)
    }

    @Test func 七日移動平均はその日で終わる7日の合計を7で割る() {
        // 8日前から今日まで毎日14ドパ。今日だけ28ドパ
        let records = (0...8).map { record(daysAgo: $0, 8, reps: $0 == 0 ? 28 : 14) }
        let h = history(records)
        #expect(h.days.last?.average == Double(14 * 6 + 28) / 7)
        #expect(h.days[h.days.count - 2].average == 14)
    }

    @Test func 記録を始める前の日は0ドパとして数える() {
        let h = history([record(daysAgo: 0, 8, reps: 21)])
        #expect(h.days.last?.average == 3)
    }

    @Test func 午前1時の記録は前の日の列の上端に入る() {
        // 5日の25時（6日の午前1時）は、記録日では5日
        let h = history([record(daysAgo: 1, 25)])
        let day = h.days.first { !$0.entries.isEmpty }
        #expect(day?.day == today.adding(days: -1))
        #expect(day?.entries.first?.minute == 21 * 60)
    }

    @Test func 叩き始めた時刻は午前4時からの分() {
        let h = history([record(daysAgo: 0, 4), record(daysAgo: 0, 12, 41)])
        #expect(h.days.last?.entries.map(\.minute) == [0, 8 * 60 + 41])
    }

    @Test func 休み券を使った日に印が付く() {
        let h = history([record(daysAgo: 3, 8), record(daysAgo: 1, 8)], rest: [today.adding(days: -2)])
        #expect(h.days.filter(\.usedRestPass).map(\.day) == [today.adding(days: -2)])
    }

    @Test func 今日より後の記録は並べない() {
        let h = history([record(daysAgo: -1, 8)])
        #expect(h.days.last?.day == today)
        #expect(h.isEmpty)
    }
}
