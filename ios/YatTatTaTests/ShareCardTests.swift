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

    @Test func 関数に送る数字は7マスを0と1と2の7文字にする() {
        var daily: Ledger.DailyReps = [:]
        for back in 2...8 { daily[today.adding(days: -back)] = 20 }
        daily[today] = 45
        let card = ShareCard(ledger: Ledger(daily: daily, today: today), daily: daily, todaySets: 2)
        let data = card.requestData(language: "ja")
        #expect(data["week"] as? String == "1111121")
        #expect(data["day"] as? Int == 20261009)
        #expect(data["streak"] as? Int == card.streak)
        #expect(data["today"] as? Int == 45)
        #expect(data["dpw"] as? Int == card.dopaPerWeek)
        #expect(data["lang"] as? String == "ja")
    }

    @MainActor @Test func Xの投稿画面には文とURLを分けて渡す() throws {
        let card = ShareCard(ledger: Ledger(daily: [today: 20], today: today), daily: [today: 20], todaySets: 1)
        let link = URL(string: "https://yat-tat-ta.web.app/s/0123456789abcdef0123")!
        let url = ShareService.intent(.x, card: card, link: link)
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(url.host() == "x.com")
        #expect(items.first { $0.name == "url" }?.value == link.absoluteString)
        #expect(items.first { $0.name == "text" }?.value?.contains("1") == true)
    }

    @MainActor @Test func LINEには文の最後にURLを付けて渡す() throws {
        let card = ShareCard(ledger: Ledger(daily: [today: 20], today: today), daily: [today: 20], todaySets: 1)
        let link = URL(string: "https://yat-tat-ta.web.app/s/0123456789abcdef0123")!
        let url = ShareService.intent(.line, card: card, link: link)
        let text = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first?.value)
        #expect(url.host() == "line.me")
        #expect(text.hasSuffix("\n" + link.absoluteString))
    }

    @MainActor @Test func XアプリにはmessageでURLを文の最後に付けて渡す() throws {
        let card = ShareCard(ledger: Ledger(daily: [today: 20], today: today), daily: [today: 20], todaySets: 1)
        let link = URL(string: "https://yat-tat-ta.web.app/s/0123456789abcdef0123")!
        let url = ShareService.xApp(card: card, link: link)
        let message = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "message" }?.value)
        #expect(url.scheme == "twitter")
        #expect(url.host() == "post")
        #expect(message.hasSuffix(" " + link.absoluteString))
    }
}
