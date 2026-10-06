#if DEBUG
import Foundation
import Observation
import QuartzCore

/// 計測モードで数える3つ。描画、タッチ→発火、途中で切った音
///
/// 叩いている間の数は画面に1秒ごとにまとめて出す。1打ごとに札を描き直すと、
/// 測っているものに札の重さが混ざるから。
@Observable final class PerfMonitor {
    /// 計測モードのときだけある。叩く面と FeelEngine がここへ知らせる
    static var shared: PerfMonitor?

    /// 50ms 以上止まったら、詰まり1回と数える
    static let hitchThreshold: CFTimeInterval = 0.05

    struct Cut: Equatable {
        let label: String
        let isVoice: Bool
        /// 鳴り終わるまで残っていた秒数
        let left: TimeInterval
        /// 鳴り始めていたか。鳴る前に上書きされたら false
        let started: Bool
    }

    /// 叩いている間に出す数。1秒ごとに更新する
    struct Live: Equatable {
        var fps = 0
        var minFps: Int?
        var hitches = 0
        var lastLatency: Double?
        var maxLatency: Double?
        var cuts = 0
        var taps = 0
    }

    /// 場面ごとの数。落ちた場所で、直すところが変わる
    struct PhaseStat: Equatable {
        let name: String
        var minFps: Int?
        var hitches = 0
        var maxLatency: Double?
    }

    /// 場面の並び。まとめの札はこの順に出す
    static let phaseOrder = ["NORMAL", "CHANCE", "激熱", "PUSH", "フィーバー", "フィナーレ"]

    struct Summary: Equatable {
        let run: Int
        let taps: Int
        let minFps: Int?
        let hitches: Int
        let median: Double
        let p95: Double
        let max: Double
        let cuts: [Cut]
        let phases: [PhaseStat]

        var voiceCuts: [Cut] { cuts.filter(\.isVoice) }
    }

    private(set) var running = false
    private(set) var live = Live()
    private(set) var summary: Summary?
    private(set) var run = 1

    @ObservationIgnored private var link: CADisplayLink?
    @ObservationIgnored private var lastFrame: CFTimeInterval = 0
    @ObservationIgnored private var bucketStart: CFTimeInterval = 0
    @ObservationIgnored private var bucketFrames = 0
    @ObservationIgnored private var minFps: Int?
    @ObservationIgnored private var hitches = 0
    @ObservationIgnored private var latencies: [Double] = []
    @ObservationIgnored private var cuts: [Cut] = []
    /// いまの場面の名前。計測モードの起動で、AppModel の状態から決める関数を入れる
    @ObservationIgnored var phase: () -> String = { "NORMAL" }
    @ObservationIgnored private var phases: [String: PhaseStat] = [:]
    /// この1秒の中で、場面ごとに何コマ描いたか。1秒の描画の回数は、いちばん長くいた場面に付ける
    @ObservationIgnored private var bucketPhases: [String: Int] = [:]

    func start() {
        let link = CADisplayLink(target: FrameTarget(self), selector: #selector(FrameTarget.frame(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 80, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    /// 指が触れた時刻（touch.timestamp）。音、振動、光の命令を出し終えたところで呼ぶ
    func tapFired(touchedAt timestamp: TimeInterval) {
        guard summary == nil else { return }
        if !running { begin() }
        let latency = (ProcessInfo.processInfo.systemUptime - timestamp) * 1000
        latencies.append(latency)
        update(phase()) { $0.maxLatency = max($0.maxLatency ?? 0, latency) }
    }

    private func update(_ name: String, _ change: (inout PhaseStat) -> Void) {
        var stat = phases[name] ?? PhaseStat(name: name)
        change(&stat)
        phases[name] = stat
    }

    func soundCut(_ cut: Cut) {
        guard running else { return }
        cuts.append(cut)
    }

    /// フィナーレが消えたら、まとめの札にする
    func finish() {
        guard running else { return }
        running = false
        let sorted = latencies.sorted()
        func percentile(_ p: Double) -> Double {
            sorted.isEmpty ? 0 : sorted[min(sorted.count - 1, Int((Double(sorted.count - 1) * p).rounded()))]
        }
        summary = Summary(run: run, taps: latencies.count, minFps: minFps, hitches: hitches,
                          median: percentile(0.5), p95: percentile(0.95), max: sorted.last ?? 0, cuts: cuts,
                          phases: Self.phaseOrder.compactMap { phases[$0] })
    }

    /// 「もう1回」。数を全部消して、次の1打を待つ
    func reset() {
        running = false
        summary = nil
        run += 1
        live = Live()
    }

    private func begin() {
        running = true
        minFps = nil
        hitches = 0
        latencies = []
        cuts = []
        phases = [:]
        bucketPhases = [:]
        bucketStart = 0
    }

    fileprivate func frame(_ link: CADisplayLink) {
        let t = link.timestamp
        defer { lastFrame = t }
        guard running, lastFrame > 0 else { return }
        let name = phase()
        if t - lastFrame >= Self.hitchThreshold {
            hitches += 1
            update(name) { $0.hitches += 1 }
        }
        if bucketStart == 0 {
            bucketStart = t
            bucketFrames = 0
            bucketPhases = [:]
            return
        }
        bucketFrames += 1
        bucketPhases[name, default: 0] += 1
        guard t - bucketStart >= 1 else { return }
        let fps = Int((Double(bucketFrames) / (t - bucketStart)).rounded())
        minFps = min(minFps ?? fps, fps)
        if let main = bucketPhases.max(by: { $0.value < $1.value })?.key {
            update(main) { $0.minFps = min($0.minFps ?? fps, fps) }
        }
        bucketStart = t
        bucketFrames = 0
        bucketPhases = [:]
        live = Live(fps: fps, minFps: minFps, hitches: hitches, lastLatency: latencies.last,
                    maxLatency: latencies.max(), cuts: cuts.filter(\.isVoice).count, taps: latencies.count)
    }
}

/// CADisplayLink は target を強く持つので、PerfMonitor を弱く持つ中継を挟む
private final class FrameTarget: NSObject {
    weak var monitor: PerfMonitor?

    init(_ monitor: PerfMonitor) {
        self.monitor = monitor
    }

    @objc func frame(_ link: CADisplayLink) {
        monitor?.frame(link)
    }
}
#endif
