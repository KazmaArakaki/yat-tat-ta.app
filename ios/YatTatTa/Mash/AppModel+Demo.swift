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
        /// SNS の動画用。叩かずに、完了連打を最初の1打からフィナーレまで流す
        case reel
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
        case .reel: runReel()
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

    /// SNS の動画の1本。docs/sessions/20261007-1727-sns-marketing/x-video.html
    ///
    /// 寝ているスクワットマンを少し見せてから起こし、20回を叩く。間隔は少しずつ詰め、勢いが付いていくように見せる。
    /// 14打目（激熱のあと）でフィーバーを当て、5秒の間は細かく叩く。叩き切ってフィナーレが消えたら終わり。
    /// 叩いた場所には指の印を出す（シミュレーターの録画には指が写らない）。
    /// `-recordAudio` があれば、その間の音を Documents に書く。動画は ios/Design/reel.sh で作る。
    enum Reel {
        /// 起動してから起こすまで。寝ている姿と、頭の文字を見せる間
        static let lead: TimeInterval = 2.0
        static let reps = 20
        static let feverAt = 14
        static let feverInterval: TimeInterval = 0.11
        static let recordAudioArgument = "-recordAudio"
        static var audioURL: URL { URL.documentsDirectory.appending(path: "reel.caf") }
        /// 書き終えた合図。録った音の始まりの時刻（1970年からの秒）と、場面の時刻（音の始まりからの秒）
        static var doneURL: URL { URL.documentsDirectory.appending(path: "reel.json") }
        /// LP の動画。叩き切ったあとの共有の誘いまで録る
        static let shareArgument = "-reelShare"
        /// 共有の誘いを見せる秒数
        static let shareSeconds: TimeInterval = 4.5

        /// n 打目のあとの間。0.6秒から詰めていき、0.28秒で止める
        static func interval(after n: Int) -> TimeInterval { max(0.28, 0.62 - 0.026 * Double(n)) }
    }

    /// 指の印。画面の幅と高さに対する割合
    struct DemoTouch: Equatable {
        let id: Int
        let x: Double
        let y: Double
    }

    private func runReel() {
        targetReps = Reel.reps
        let records = ProcessInfo.processInfo.arguments.contains(Reel.recordAudioArgument)
        try? FileManager.default.removeItem(at: Reel.doneURL)
        let audioStart = Date.now.timeIntervalSince1970
        if records { feel.startRecording(to: Reel.audioURL) }
        Task { [weak self] in
            func uptime() -> TimeInterval { ProcessInfo.processInfo.systemUptime }
            var events: [String: TimeInterval] = [:]
            func mark(_ name: String) {
                if events[name] == nil { events[name] = Date.now.timeIntervalSince1970 - audioStart }
            }
            // 叩く場所は、スクワットマンのあたりで少しずつずらす。種を決めて、毎回同じにする
            var seed: UInt64 = 20261007
            func jitter() -> Double {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                return Double(seed >> 11) / Double(1 << 53) * 2 - 1
            }
            var touches = 0
            func touch(spread: Double) {
                touches += 1
                demoTouch = DemoTouch(id: touches, x: 0.5 + jitter() * 0.16 * spread, y: 0.52 + jitter() * 0.07 * spread)
            }

            try? await Task.sleep(for: .seconds(Reel.lead))
            guard let self else { return }
            mark("wake")
            wake()
            try? await Task.sleep(for: .seconds(0.7))
            let lottery = draw
            var squats = 0
            while squats < Reel.reps {
                let hitsFever = squats + 1 == Reel.feverAt
                draw = { hitsFever ? 0 : 1 }
                touch(spread: 1)
                guard let tap = tap(at: uptime()) else { break }
                squats = tap.index
                mark("tap")
                if tap.enteredStage { mark("\(tap.stage)") }
                if tap.startedFever {
                    mark("fever")
                    let end = uptime() + MashSession.feverDuration - 0.1
                    while uptime() < end {
                        try? await Task.sleep(for: .seconds(Reel.feverInterval))
                        touch(spread: 2)
                        _ = self.tap(at: uptime())
                    }
                    try? await Task.sleep(for: .seconds(0.5))
                    mark("feverEnd")
                }
                if tap.isFinal { mark("final"); break }
                try? await Task.sleep(for: .seconds(Reel.interval(after: squats)))
            }
            draw = lottery
            // フィナーレが出て、消えるまで待つ
            try? await Task.sleep(for: .seconds(1.5))
            while finale != nil { try? await Task.sleep(for: .seconds(0.1)) }
            try? await Task.sleep(for: .seconds(0.3))
            // LP の動画では、そのあと出る共有の誘いを見せてから終える（ios/Design/reel.sh lp）
            if ProcessInfo.processInfo.arguments.contains(Reel.shareArgument) {
                for _ in 0..<20 where !showsSharePrompt { try? await Task.sleep(for: .seconds(0.1)) }
                mark("share")
                try? await Task.sleep(for: .seconds(Reel.shareSeconds))
            }
            mark("end")
            if records { feel.stopRecording() }
            let done = try? JSONSerialization.data(withJSONObject: ["audioStart": audioStart, "events": events])
            try? done?.write(to: Reel.doneURL)
        }
    }
}
#endif
