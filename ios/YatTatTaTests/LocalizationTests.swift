import Foundation
import Testing
@testable import YatTatTa

/// 日本語と英語の文言がそろっているか
///
/// 開発の言語（端末がどちらの言語でもないときの言語）を英語にしているので、
/// 日本語の値が抜けると、日本語の端末にも英語が出る。String Catalog に両方を入れる決まり（docs/devops/localization）。
struct LocalizationTests {
    private static let catalogURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("YatTatTa/Localizable.xcstrings")

    private struct Catalog: Decodable {
        let strings: [String: Entry]
        struct Entry: Decodable { let localizations: [String: Localization]? }
        struct Localization: Decodable { let stringUnit: Unit? }
        struct Unit: Decodable { let value: String }
    }

    private func catalog() throws -> Catalog {
        try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: Self.catalogURL))
    }

    /// %lld や %@、%1$lld のような差し込みの数
    private func placeholders(_ s: String) -> Int {
        s.matches(of: /%(\d+\$)?(lld|@|d|ld)/).count
    }

    @Test func すべての文言に日本語と英語がある() throws {
        for (key, entry) in try catalog().strings {
            for language in ["ja", "en"] {
                let value = entry.localizations?[language]?.stringUnit?.value
                #expect(value?.isEmpty == false, "\(language) がない：\(key)")
            }
        }
    }

    @Test func 英語にも同じ数の差し込みがある() throws {
        for (key, entry) in try catalog().strings {
            guard let en = entry.localizations?["en"]?.stringUnit?.value else { continue }
            #expect(placeholders(en) == placeholders(key), "差し込みの数が違う：\(key)")
        }
    }

    @Test func アプリに日本語と英語の表が入っている() {
        for language in ["ja", "en"] {
            #expect(Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: nil,
                                     forLocalization: language) != nil, "\(language) の表がない")
        }
    }
}
