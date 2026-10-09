import Foundation
import Testing
@testable import YatTatTa

/// 共有する今日の記録カードの中身
struct ShareCardTests {
    private let today = RecordDay(year: 2026, month: 10, day: 9)

    @Test func 七日分のマス目は古い順で今日が最後() {
        let daily: Ledger.DailyReps = [today: 40, today.adding(days: -1): 20, today.adding(days: -6): 20]
        let card = ShareCard(ledger: Ledger(daily: daily, today: today), daily: daily, todaySets: 2)
        #expect(card.week == [.done, .none, .none, .none, .none, .done, .done])
        #expect(card.todayDopa == 40)
        #expect(card.todaySets == 2)
        #expect(card.dopaPerWeek == 80)
    }

    @Test func 休み券でつないだ日は休み券のマス() {
        // 7日続けて休み券を1枚もらい、1日休んで、今日叩いた
        var daily: Ledger.DailyReps = [:]
        for back in 2...8 { daily[today.adding(days: -back)] = 20 }
        daily[today] = 20
        let ledger = Ledger(daily: daily, today: today)
        let card = ShareCard(ledger: ledger, daily: daily, todaySets: 1)
        #expect(card.week[5] == .rest)
        #expect(card.week[6] == .done)
        #expect(card.streak == ledger.streak.current)
        #expect(card.doneToday)
    }

    @Test func 今日まだ叩いていなければ今日は空のマス() {
        let daily: Ledger.DailyReps = [today.adding(days: -1): 20]
        let card = ShareCard(ledger: Ledger(daily: daily, today: today), daily: daily, todaySets: 0)
        #expect(card.week.last == ShareCard.Cell.none)
        #expect(card.todayDopa == 0)
        #expect(!card.doneToday)
    }
}
