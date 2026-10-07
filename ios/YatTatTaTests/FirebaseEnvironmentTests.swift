import Foundation
import Testing
@testable import YatTatTa

/// Debug のビルドに、開発用の Firebase の設定が入っているか
///
/// テストは Debug で動くので、ここで本番のプロジェクトが見えたら、写す設定ファイルを取り違えている。
/// 取り違えると、開発の試し打ちが利用者の記録に混ざる（docs/devops/firebase#environments）。
struct FirebaseEnvironmentTests {
    private func projectID() throws -> String {
        let url = try #require(Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist"))
        let plist = try #require(NSDictionary(contentsOf: url))
        return try #require(plist["PROJECT_ID"] as? String)
    }

    @Test func DebugのビルドはFirebaseの本番のプロジェクトに書かない() throws {
        let id = try projectID()
        #expect(id != "yat-tat-ta")
        #expect(id.hasPrefix("yat-tat-ta-dev"))
    }
}
