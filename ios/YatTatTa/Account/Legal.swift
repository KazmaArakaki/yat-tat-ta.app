import Foundation

/// 公開ページの URL。Firebase Hosting で出している（docs/devops/firebase#hosting）
///
/// URL を変えると、出したアプリから開けなくなる。App Store Connect にも同じ URL を入れている。
enum Legal {
    static let site = URL(string: "https://yat-tat-ta.web.app/")!

    /// アプリの文言と同じ言語のページ。日本語のときだけ日本語で、ほかは英語
    static var privacyPolicy: URL { privacyPolicy(language: Bundle.main.preferredLocalizations.first) }

    static func privacyPolicy(language: String?) -> URL {
        site.appending(path: language == "ja" ? "privacy/" : "privacy/en/")
    }
}
