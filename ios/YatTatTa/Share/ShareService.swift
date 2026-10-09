import FirebaseFunctions
import Foundation
import UIKit

/// 共有する先。共有の誘いと、今日の記録のシートに、この3つを並べる
enum ShareTarget: CaseIterable {
    case line, x, other
}

/// 今日の記録カードを、LINE、X、ほかのアプリへ渡す（docs/features/share-card）
///
/// LINE と X の投稿画面に、アプリから画像は渡せない。渡せるのは文と URL だけ。
/// そこで、カードの数字を関数（createShareCard）に送ってリンクカードを作ってもらい、その URL を渡す。
/// LINE と X は URL を読みに来て、カードを出す。電波がない、関数が失敗したときは、共有シートで画像ごと渡す。
@MainActor enum ShareService {
    /// 渡したら true。LINE と X は投稿したかまで分からないので、投稿画面を開けたら渡したことにする
    static func share(_ card: ShareCard, to target: ShareTarget) async -> Bool {
        switch target {
        case .other:
            return await sheet(card)
        case .line, .x:
            do {
                let url = try await linkCard(for: card)
                // X は、アプリを直接開く。x.com の投稿口はアプリの中のブラウザで開き、ログインしていない
                if target == .x, await UIApplication.shared.open(xApp(card: card, link: url)) { return true }
                let opened = await UIApplication.shared.open(intent(target, card: card, link: url))
                return opened ? true : await sheet(card)
            } catch {
                print("Share: \(error)")
                return await sheet(card)
            }
        }
    }

    /// X アプリの投稿画面。アプリが入っていなければ開けない（open が false を返す）
    ///
    /// 文と URL を分けて渡す口はないので、文の最後に URL を付ける。
    static func xApp(card: ShareCard, link: URL) -> URL {
        var components = URLComponents()
        components.scheme = "twitter"
        components.host = "post"
        components.queryItems = [URLQueryItem(name: "message", value: message(card) + " " + link.absoluteString)]
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        return components.url!
    }

    private static func message(_ card: ShareCard) -> String {
        String(localized: "Yat Tat Ta で\(card.streak)日連続。食べたら、しゃがんで、叩く。")
    }

    /// 投稿画面を開く URL。LINE はアプリが入っていればアプリが開く。X はアプリが入っていないときだけ使う
    static func intent(_ target: ShareTarget, card: ShareCard, link: URL) -> URL {
        let message = message(card)
        var components: URLComponents
        switch target {
        case .x:
            components = URLComponents(string: "https://x.com/intent/post")!
            components.queryItems = [URLQueryItem(name: "text", value: message), URLQueryItem(name: "url", value: link.absoluteString)]
        case .line, .other:
            // LINE は文だけを受け取る。URL は文の最後に付ける
            components = URLComponents(string: "https://line.me/R/share")!
            components.queryItems = [URLQueryItem(name: "text", value: message + "\n" + link.absoluteString)]
        }
        // + を空白と読む相手がいるので、文の中の + も逃がす
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        return components.url!
    }

    /// 関数に数字を送り、リンクカードの URL をもらう
    private static func linkCard(for card: ShareCard) async throws -> URL {
        let result = try await Functions.functions(region: "asia-northeast1")
            .httpsCallable("createShareCard")
            .call(card.requestData(language: language))
        guard let text = (result.data as? [String: Any])?["url"] as? String, let url = URL(string: text) else {
            throw URLError(.badServerResponse)
        }
        return url
    }

    /// カードの言語。アプリの文言と同じ言語にする
    private static var language: String {
        Bundle.main.preferredLocalizations.first == "ja" ? "ja" : "en"
    }

    private static func sheet(_ card: ShareCard) async -> Bool {
        await withCheckedContinuation { continuation in
            if !ShareSheet.present(card, completion: { continuation.resume(returning: $0) }) {
                continuation.resume(returning: false)
            }
        }
    }
}

extension ShareCard {
    /// 関数に送る数字。7マスは、空が 0、叩いた日が 1、休み券の日が 2 の7文字
    func requestData(language: String) -> [String: Any] {
        let week = week.map { cell in
            switch cell {
            case .none: "0"
            case .done: "1"
            case .rest: "2"
            }
        }.joined()
        return ["lang": language, "day": today.value, "streak": streak, "week": week, "today": todayDopa, "dpw": dopaPerWeek]
    }
}
