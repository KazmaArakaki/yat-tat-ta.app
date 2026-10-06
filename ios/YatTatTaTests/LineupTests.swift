import Foundation
import Testing
@testable import YatTatTa

struct LineupTests {
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return c
    }()
    /// 2026-10-07 は水曜
    private let today = RecordDay(year: 2026, month: 10, day: 7)
    /// 日曜始まり
    private let sunday = 1

    private func lineup(_ s: Ledger.Streak, firstWeekday: Int = 1) -> Lineup {
        Lineup(streak: s, today: today, firstWeekday: firstWeekday, calendar: calendar)
    }

    private func streak(current: Int, doneToday: Bool = false, best: Int = 0, rest: [Int] = []) -> Ledger.Streak {
        var s = Ledger.Streak()
        s.current = current
        s.doneToday = doneToday
        s.best = max(best, current)
        s.restPassDays = rest.map { today.adding(days: -$0) }
        return s
    }

    @Test func はじめては今日の席だけ() {
        let l = lineup(streak(current: 0))
        #expect(l.isSeatOnly)
        #expect(l.cells.last == .seat)
        #expect(l.hidden == 0)
    }

    @Test func 途切れたあとも前の日を並べない() {
        let l = lineup(streak(current: 0, best: 12))
        #expect(l.isSeatOnly)
        #expect(!l.cells.contains(.past))
    }

    @Test func 今日の席は今日の曜日の列に来る() {
        // 水曜は日曜始まりで4列目（0から数えて3）
        let l = lineup(streak(current: 2))
        #expect(l.cells == [.blank, .past, .past, .seat])
        // 月曜始まりなら3列目（0から数えて2）
        let m = lineup(streak(current: 2), firstWeekday: 2)
        #expect(m.cells == [.past, .past, .seat])
    }

    @Test func 今日済みなら今日のマスに人形が立つ() {
        let l = lineup(streak(current: 3, doneToday: true))
        #expect(l.cells == [.blank, .past, .past, .today])
    }

    @Test func 休み券の日は札で挟まる() {
        // 昨日と4日前に休み券。叩いた日は5日
        let l = lineup(streak(current: 5, rest: [1, 4]))
        #expect(l.cells.filter { $0 == .rest }.count == 2)
        #expect(l.cells.filter { $0 == .past }.count == 5)
        #expect(Array(l.cells.suffix(2)) == [.rest, .seat])
        #expect(l.cells.count % 7 == 4)
    }

    @Test func 連続より古い休み券は並べない() {
        // 30日前の休み券は、いまの3日連続より前
        let l = lineup(streak(current: 3, rest: [30]))
        #expect(!l.cells.contains(.rest))
    }

    @Test func 二十九日連続は五週() {
        let l = lineup(streak(current: 29, rest: [9, 20]))
        #expect(l.rows == 5)
        #expect(l.cells.filter { $0 == .past }.count == 29)
        #expect(l.hidden == 0)
    }

    @Test func 八週を超えたら古い週をまとめる() {
        let l = lineup(streak(current: 100))
        #expect(l.rows == Lineup.maxWeeks)
        #expect(l.cells.count <= Lineup.maxWeeks * 7)
        #expect(l.hidden + l.cells.filter { $0 == .past }.count == 100)
        #expect(l.cells.last == .seat)
    }
}
