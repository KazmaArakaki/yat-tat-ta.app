import SwiftData
import SwiftUI

@main struct YatTatTaApp: App {
    private let container: ModelContainer
    @State private var model: AppModel
    #if DEBUG
    /// 計測モード（起動引数 -perf）のときだけある
    private let perf: PerfMonitor?
    private let feverDraw = PerfSeed.FeverDraw()
    #endif

    init() {
        #if DEBUG
        let perfOn = PerfSeed.isOn
        #else
        let perfOn = false
        #endif
        do {
            // 計測モードは、メモリだけの保存先を使う。端末に保存された記録には触れない
            container = try ModelContainer(
                for: SquatRecord.self, configurations: ModelConfiguration(isStoredInMemoryOnly: perfOn))
        } catch {
            fatalError("SwiftData: \(error)")
        }
        #if DEBUG
        if perfOn {
            let records = PerfSeed.records(today: RecordDay(.now), now: .now)
            records.forEach(container.mainContext.insert)
            try? container.mainContext.save()
            let model = AppModel(context: container.mainContext, defaults: PerfSeed.defaults())
            model.remindersPaused = true
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
            _model = State(initialValue: model)
            return
        }
        perf = nil
        #endif
        let model = AppModel(context: container.mainContext)
        model.feel.start()
        _model = State(initialValue: model)
    }

    var body: some Scene {
        WindowGroup {
            HomeView(model: model)
                #if DEBUG
                .overlay(alignment: .topLeading) {
                    if let perf {
                        PerfHUD(monitor: perf, model: model) {
                            feverDraw.reset()
                            model.resetForPerf(PerfSeed.records(today: RecordDay(.now), now: .now))
                            perf.reset()
                        }
                    }
                }
                #endif
        }
        .modelContainer(container)
    }
}
