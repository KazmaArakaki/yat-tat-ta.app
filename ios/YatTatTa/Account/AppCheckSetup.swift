import FirebaseAppCheck
import FirebaseCore

/// Firebase への問い合わせが本物の Yat Tat Ta から来たかを、App Check で確かめる（docs/devops/firebase#environments）
///
/// FirebaseApp.configure() より前に呼ぶ。Release は App Attest で Apple が確かめる。
/// シミュレーターでは App Attest が動かないので、Debug はデバッグ用のトークンを使う。
/// トークンは初めて起動したときに Xcode のコンソールに出るので、開発用のプロジェクトに登録する。
enum AppCheckSetup {
    static func install() {
        #if DEBUG
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        #else
        AppCheck.setAppCheckProviderFactory(AppAttestFactory())
        #endif
    }
}

private final class AppAttestFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        AppAttestProvider(app: app)
    }
}
