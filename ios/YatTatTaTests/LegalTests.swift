import Foundation
import Testing
@testable import YatTatTa

/// 公開ページの URL。App Store Connect に入れたものと食い違わないように
struct LegalTests {
    @Test func 日本語なら日本語のポリシーを開く() {
        #expect(Legal.privacyPolicy(language: "ja").absoluteString == "https://yat-tat-ta.web.app/privacy/")
    }

    @Test func 日本語でなければ英語のポリシーを開く() {
        #expect(Legal.privacyPolicy(language: "en").absoluteString == "https://yat-tat-ta.web.app/privacy/en/")
        #expect(Legal.privacyPolicy(language: nil).absoluteString == "https://yat-tat-ta.web.app/privacy/en/")
    }
}
