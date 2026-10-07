#if DEBUG
import Foundation

/// 開発用の見本。起動引数 `-demo <名前>` で、叩かずに演出の画面を出す
///
/// シミュレーターでは連打できないので、画面の確認と、重い場面の実機確認に使う。
/// 例：`xcrun simctl launch booted com.yat-tat-ta -demo kakutei`
extension AppModel {
    enum Demo: String {
        case chance, hot, push, toppa, gold, fever, kakutei, negirai, heavy, squad, splash, intro
        /// スクリーンショット用。home は何も出さない、history は履歴のシートを開く
        case home, history
        /// チュートリアルの場面。tutorial は場面1から、ほかはその場面から
        case tutorial, tutorialMash = "tutorial-mash", tutorialAfter = "tutorial-after",
             tutorialStreak = "tutorial-streak", tutorialTotals = "tutorial-totals",
             tutorialGear = "tutorial-gear", tutorialFinish = "tutorial-finish"
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
        // スクリーンショットでは、何打か叩いたところに見せる
        case .fever: setDemoFever(gained: ShotSeed.isOn ? 24 : 0)
        case .tutorial: startTutorial()
        case .tutorialMash:
            // 練習を激熱（6打目）まで叩いたところ
            startTutorial()
            wake()
            let start = ProcessInfo.processInfo.systemUptime
            for i in 0..<6 { _ = tap(at: start + Double(i) * 0.1) }
        case .tutorialAfter: setDemoTutorial(.after)
        case .tutorialStreak: setDemoTutorial(.streak)
        case .tutorialTotals: setDemoTutorial(.totals)
        case .tutorialGear: setDemoTutorial(.gear)
        case .tutorialFinish: setDemoTutorial(.finish)
        case .home: break
        case .history: demoOpensHistory = true
        case .splash: showSplash(.regular)
        case .intro: showSplash(.intro)
        case .squad:
            // 目標100で、残り3（PUSH）まで叩いたスクワットマン。20人
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
