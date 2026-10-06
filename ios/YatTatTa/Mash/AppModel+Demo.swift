#if DEBUG
import Foundation

/// 開発用の見本。起動引数 `-demo <名前>` で、叩かずに演出の画面を出す
///
/// シミュレーターでは連打できないので、画面の確認と、重い場面の実機確認に使う。
/// 例：`xcrun simctl launch booted com.yat-tat-ta -demo kakutei`
extension AppModel {
    enum Demo: String {
        case chance, hot, push, toppa, gold, fever, kakutei, negirai, heavy, squad, splash, intro
    }

    /// 見本の起動か。見本では、ふつうのスプラッシュを出さない
    static var demoRequested: Bool { ProcessInfo.processInfo.arguments.contains("-demo") }

    func runDemoFromLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-demo"), i + 1 < args.count, let demo = Demo(rawValue: args[i + 1]) else { return }
        showDemo(demo)
    }

    func showDemo(_ demo: Demo) {
        let three: [Milestone] = [.streak(30), .dopaTotal(1_000), .bestWindow(410)]
        switch demo {
        case .chance: setDemoBanner(.chance)
        case .hot: setDemoBanner(.hot)
        case .push: setDemoBanner(.push)
        case .toppa: setDemoToppa(ToppaEvent(value: 300, gold: false))
        case .gold: setDemoToppa(ToppaEvent(value: 1_000, gold: true))
        case .fever: setDemoFever()
        case .splash: showSplash(.regular)
        case .intro: showSplash(.intro)
        case .squad:
            // 目標100で、残り3（PUSH）まで叩いた隊。20人
            targetReps = 100
            let start = ProcessInfo.processInfo.systemUptime
            let lottery = draw
            draw = { 1 }
            wake()
            for i in 0..<97 { _ = tap(at: start + Double(i) * 0.01) }
            draw = lottery
        case .kakutei, .negirai:
            setDemoFinale(FinaleEvent(completed: true, reps: 20, streakExtended: 30, milestones: [.streak(30)],
                                      kakutei: 0, negirai: Negirai(headline: String(localized: "\(30)日連続！"), message: String(localized: "あんたはえらい！"),
                                                                   voice: .voiceNegirai3)),
                          skipToNegirai: demo == .negirai)
        case .heavy:
            // 一番重い1打：連続30日、DT 1,000、DPW 自己ベストが重なる
            setDemoToppa(ToppaEvent(value: 1_000, gold: true))
            setDemoFinale(FinaleEvent(completed: true, reps: 20, streakExtended: 30, milestones: three, kakutei: 0,
                                      negirai: Negirai(headline: String(localized: "\(30)日連続！"), message: String(localized: "あんたはえらい！"),
                                                       voice: .voiceNegirai3)),
                          skipToNegirai: false)
        }
    }
}
#endif
