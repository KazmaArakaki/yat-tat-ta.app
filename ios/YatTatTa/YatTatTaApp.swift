import FirebaseCore
import SwiftUI

@main struct YatTatTaApp: App {
    /// ふだんはアカウント。計測モードと演出の見本は、メモリだけの記録でログインせずに開く
    private let account: Account?
    @State private var localModel: AppModel?
    #if DEBUG
    /// 計測モード（起動引数 -perf）のときだけある
    private let perf: PerfMonitor?
    private let feverDraw = PerfSeed.FeverDraw()
    #endif

    /// テストの入れ物として起動された。Firebase に触れず、画面も出さない
    private static var isTesting: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    init() {
        #if DEBUG
        if PerfSeed.isOn {
            // 計測モードは、メモリだけの記録を使う。利用者の棚には触れない
            let store = MemoryRecordStore(records: PerfSeed.records(today: RecordDay(.now), now: .now))
            let model = AppModel(store: store, defaults: PerfSeed.defaults())
            model.remindersPaused = true
            model.splashPaused = true
            let draw = feverDraw
            model.draw = { draw.next() }
            let monitor = PerfMonitor()
            monitor.phase = {
                if model.finale != nil { return "フィナーレ" }
                if model.fever != nil || model.feverResult != nil { return "フィーバー" }
                switch model.hypeStage {
                case .normal: return "NORMAL"
                case .chance: return "CHANCE"
                case .hot: return "激熱"
                case .push: return "PUSH"
                }
            }
            PerfMonitor.shared = monitor
            monitor.start()
            perf = monitor
            model.feel.start()
            account = nil
            _localModel = State(initialValue: model)
            return
        }
        perf = nil
        if AppModel.demoRequested {
            // 演出の見本も、ログインせずにメモリだけの記録で開く
            let model = AppModel(store: MemoryRecordStore())
            model.splashPaused = true
            model.feel.start()
            account = nil
            _localModel = State(initialValue: model)
            return
        }
        #endif
        guard !Self.isTesting else {
            account = nil
            return
        }
        // Debug は開発用、Release は本番用の設定ファイルが入っている（project.yml の FIREBASE_ENV）
        AppCheckSetup.install()
        FirebaseApp.configure()
        account = Account()
    }

    var body: some Scene {
        WindowGroup {
            if let localModel {
                HomeView(model: localModel, account: nil)
                    #if DEBUG
                    .overlay(alignment: .topLeading) {
                        if let perf {
                            PerfHUD(monitor: perf, model: localModel) {
                                feverDraw.reset()
                                localModel.resetForPerf(PerfSeed.records(today: RecordDay(.now), now: .now))
                                perf.reset()
                            }
                        }
                    }
                    #endif
            } else if let account {
                AccountRoot(account: account)
            }
        }
    }
}

/// ログインの状態で、ログイン画面とホームを切り替える
private struct AccountRoot: View {
    let account: Account

    var body: some View {
        Group {
            if let model = account.model, !account.welcoming {
                HomeView(model: model, account: account)
            } else if account.state == .checking {
                // ログインしているかは、端末の中だけで一瞬で分かる。その間は地の色だけ
                Color.paper.ignoresSafeArea()
            } else {
                LoginView(account: account)
            }
        }
        .animation(.easeOut(duration: 0.25), value: account.model == nil || account.welcoming)
    }
}
