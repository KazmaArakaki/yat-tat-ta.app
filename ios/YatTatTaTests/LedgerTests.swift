import Foundation
import Testing
@testable import YatTatTa

/// 2026-10-01 から n 日後の記録日
private func d(_ n: Int) -> RecordDay { RecordDay(year: 2026, month: 10, day: 1).adding(days: n) }

/// 日のリストから、1日20回の記録を作る
private func ledger(days: [Int], reps: Int = 20, today: Int) -> Ledger {
    Ledger(records: days.map { (day: d($0), reps: reps) }, today: d(today))
}

struct RecordDayTests {
    private func date(_ s: String, _ tz: String) -> (Date, Calendar) {
        let f = ISO8601DateFormatter()
        f.timeZone = TimeZone(identifier: tz)
        f.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime, .withDashSeparatorInDate]
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: tz)!
        return (f.date(from: s)!, c)
    }

    @Test func 午前4時より前は前の日() {
        let (early, c) = date("2026-10-07T03:59:00", "Asia/Tokyo")
        #expect(RecordDay(early, calendar: c) == RecordDay(year: 2026, month: 10, day: 6))
        let (four, _) = date("2026-10-07T04:00:00", "Asia/Tokyo")
        #expect(RecordDay(four, calendar: c) == RecordDay(year: 2026, month: 10, day: 7))
    }

    @Test func 月と年をまたいで足し引きできる() {
        let last = RecordDay(year: 2026, month: 12, day: 31)
        #expect(last.adding(days: 1) == RecordDay(year: 2027, month: 1, day: 1))
        #expect(RecordDay(year: 2027, month: 3, day: 1).adding(days: -1) == RecordDay(year: 2027, month: 2, day: 28))
        #expect(RecordDay(year: 2027, month: 1, day: 1).days(since: last) == 1)
    }

    @Test func 夏時間の切り替わりでも1日は1日() {
        // アメリカの夏時間が終わる日（2026-11-01）をまたぐ
        let (before, c) = date("2026-10-31T22:00:00", "America/Los_Angeles")
        let (after, _) = date("2026-11-01T22:00:00", "America/Los_Angeles")
        #expect(RecordDay(after, calendar: c).days(since: RecordDay(before, calendar: c)) == 1)
    }
}

struct DopaTests {
    @Test func DTはこれまでの全部() {
        let l = Ledger(records: [(day: d(0), reps: 20), (day: d(0), reps: 7), (day: d(40), reps: 30)], today: d(40))
        #expect(l.dopaTotal == 57)
    }

    @Test func DPWは今日と前の6日() {
        // 6日前は入り、7日前は入らない
        let l = ledger(days: [0, 1, 7], today: 7)
        #expect(l.dopaPerWeek == 40)
        #expect(l.previousWindow == 20)
    }

    @Test func DPWは叩かなくても7日前の分が抜けて減る() {
        #expect(ledger(days: [0], today: 6).dopaPerWeek == 20)
        #expect(ledger(days: [0], today: 7).dopaPerWeek == 0)
    }

    @Test func 自己ベストは記録を始めて8日目から() {
        #expect(ledger(days: [0], today: 6).bestWindow == nil)
        #expect(ledger(days: [0], today: 7).bestWindow == 20)
    }

    @Test func 自己ベストに今日は入らない() {
        let l = ledger(days: [0, 1, 2, 10, 10, 10, 10], today: 10)
        #expect(l.bestWindow == 60)
        #expect(l.dopaPerWeek == 80)
    }
}

struct StreakTests {
    @Test func 記録がなければ0日() {
        let s = ledger(days: [], today: 0).streak
        #expect(s == Ledger.Streak())
        #expect(s.nextCount == 1)
    }

    @Test func 今日まだでも途切れていない() {
        let s = ledger(days: [0, 1, 2], today: 3).streak
        #expect(s.current == 3)
        #expect(!s.doneToday)
        #expect(s.nextCount == 4)
        #expect(s.lastBreak == nil)
    }

    @Test func 同じ日に何回叩いても1日() {
        let s = ledger(days: [0, 0, 0, 1], today: 1).streak
        #expect(s.current == 2)
        #expect(s.doneToday)
    }

    @Test func 七日ごとに休み券を1枚もらい2枚まで() {
        #expect(ledger(days: Array(0..<6), today: 5).streak.restPasses == 0)
        #expect(ledger(days: Array(0..<7), today: 6).streak.restPasses == 1)
        #expect(ledger(days: Array(0..<21), today: 20).streak.restPasses == 2)
    }

    @Test func 休み券で埋めた日は数えない() {
        // 7日続けて1枚もらい、8日目を休み、9日目に叩く
        let s = ledger(days: Array(0..<7) + [8], today: 8).streak
        #expect(s.current == 8)
        #expect(s.restPasses == 0)
        #expect(s.restPassDays == [d(7)])
        #expect(s.lastBreak == nil)
    }

    @Test func 休み券がなければ途切れる() {
        let s = ledger(days: Array(0..<7) + [10], today: 10).streak
        // 7日目で1枚。8日目に使い、9日目に途切れる
        #expect(s.restPassDays == [d(7)])
        #expect(s.lastBreak == .init(day: d(8), length: 7))
        #expect(s.current == 1)
        #expect(s.best == 7)
        #expect(s.restPasses == 0)
    }

    @Test func 途切れたあと今日まだなら0日で次は1日目() {
        let s = ledger(days: [0, 1, 2], today: 5).streak
        #expect(s.current == 0)
        #expect(s.nextCount == 1)
        #expect(s.lastBreak == .init(day: d(3), length: 3))
        #expect(s.best == 3)
    }

    @Test func 二枚続けて使える() {
        let s = ledger(days: Array(0..<14) + [16], today: 16).streak
        #expect(s.restPassDays == [d(14), d(15)])
        #expect(s.current == 15)
        #expect(s.restPasses == 0)
    }
}

struct MilestoneTests {
    @Test func DTの節目はまたいだ1打で出る() {
        #expect(Milestone.dopaTotal(from: 99, to: 100) == [.dopaTotal(100)])
        #expect(Milestone.dopaTotal(from: 100, to: 101) == [])
        #expect(Milestone.dopaTotal(from: 980, to: 1_000) == [.dopaTotal(1_000)])
    }

    @Test func 連続の節目は365日を超えたら365日ごと() {
        #expect(Milestone.streak(reaching: 7) == .streak(7))
        #expect(Milestone.streak(reaching: 8) == nil)
        #expect(Milestone.streak(reaching: 730) == .streak(730))
        #expect(Milestone.streak(reaching: 731) == nil)
    }

    @Test func 自己ベストは超えた1打だけ() {
        #expect(Milestone.bestWindow(best: 410, from: 410, to: 411) == .bestWindow(410))
        #expect(Milestone.bestWindow(best: 410, from: 411, to: 412) == nil)
        #expect(Milestone.bestWindow(best: 410, from: 409, to: 410) == nil)
        #expect(Milestone.bestWindow(best: nil, from: 0, to: 1) == nil)
    }
}

struct HypeStageTests {
    @Test func 目標20ならCHANCEと激熱とPUSHに入る打が決まっている() {
        let stages = (1...20).map { MashSession.stage(index: $0, target: 20) }
        #expect(stages.firstIndex(of: .chance).map { $0 + 1 } == 6)
        #expect(stages.firstIndex(of: .hot).map { $0 + 1 } == 12)
        #expect(stages.firstIndex(of: .push).map { $0 + 1 } == 17)
    }

    @Test func 目標5でも段階は下がらず最後はPUSH() {
        let stages = (1...5).map { MashSession.stage(index: $0, target: 5) }
        #expect(stages == stages.sorted())
        #expect(stages.last == .push)
    }

    @Test func 速く叩き続けると打数が数えられ間が空くと1に戻る() {
        var s = MashSession(target: 20)
        let miss = { 1.0 }
        _ = s.tap(at: 0, date: .now, target: 20, draw: miss)
        _ = s.tap(at: 0.3, date: .now, target: 20, draw: miss)
        #expect(s.tap(at: 0.6, date: .now, target: 20, draw: miss)?.combo == 3)
        #expect(s.tap(at: 2.0, date: .now, target: 20, draw: miss)?.combo == 1)
    }

    @Test func 最後の1打でフィーバーが当たったら終わってから数えない間に入る() {
        var s = MashSession(target: 2)
        _ = s.tap(at: 0, date: .now, target: 2, draw: { 1 })
        let last = s.tap(at: 0.2, date: .now, target: 2, draw: { 0 })
        #expect(last?.isFinal == true)
        #expect(last?.startedFever == true)
        // フィーバー中は叩ける
        #expect(s.tap(at: 1.0, date: .now, target: 2, draw: { 0 })?.isFever == true)
        s.endFever(at: 10.2)
        #expect(s.tap(at: 10.5, date: .now, target: 2, draw: { 1 }) == nil)
    }
}
