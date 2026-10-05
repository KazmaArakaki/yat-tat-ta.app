import AVFoundation
import CoreHaptics
import Observation
import QuartzCore

/// 音と振動を誰が鳴らすか
enum SyncMode: String, CaseIterable, Identifiable {
    /// 音は AVAudioEngine、振動は Core Haptics。別々に鳴らす
    case separate
    /// 音も振動も Core Haptics の1つのパターンで鳴らす
    case unified

    var id: Self { self }
    var label: String {
        switch self {
        case .separate: "A 別々"
        case .unified: "B 一体"
        }
    }
}

/// タップ1回ぶんの音と振動を鳴らす
@Observable final class FeelEngine {
    static let levelCount = ToneSynth.semitones.count
    /// この秒数以内に次のタップが来たら、段階を1つ上げる
    static let comboWindow: TimeInterval = 0.45

    // 試作画面で切り替える設定。変えたら settingsChanged() を呼ぶ
    var soundOn = true
    var hapticsOn = true
    var lightOn = true
    var mode: SyncMode = .separate
    /// 音だけをわざと遅らせる秒数
    var soundDelay: TimeInterval = 0

    // 画面に出す計測値
    private(set) var level = 0
    private(set) var touchToFireMs: Double?
    private(set) var audioLatencyMs: Double = 0
    private(set) var hapticStatus = "準備中"

    @ObservationIgnored private var lastTouchTime: TimeInterval = -.infinity

    @ObservationIgnored private let audioEngine = AVAudioEngine()
    @ObservationIgnored private var audioPlayers: [AVAudioPlayerNode] = []
    @ObservationIgnored private var nextAudioPlayer = 0
    @ObservationIgnored private var buffers: [AVAudioPCMBuffer] = []
    @ObservationIgnored private var audioURLs: [URL] = []

    @ObservationIgnored private var hapticEngine: CHHapticEngine?
    @ObservationIgnored private var audioResourceIDs: [CHHapticAudioResourceID] = []
    /// A 用。振動だけのパターン
    @ObservationIgnored private var hapticPlayers: [CHHapticPatternPlayer] = []
    /// B 用。振動と音を1つにしたパターン
    @ObservationIgnored private var unifiedPlayers: [CHHapticPatternPlayer] = []

    func start() {
        startAudio()
        startHaptics()
    }

    /// タッチ1回ぶん。段階を決めて音と振動を鳴らし、決めた段階を返す
    func touchDown(at timestamp: TimeInterval) -> Int {
        level = timestamp - lastTouchTime <= Self.comboWindow ? min(level + 1, Self.levelCount - 1) : 0
        lastTouchTime = timestamp

        switch mode {
        case .separate:
            if hapticsOn { try? hapticPlayers[safe: level]?.start(atTime: CHHapticTimeImmediate) }
            if soundOn { playBuffer(level) }
        case .unified:
            if hapticsOn || soundOn { try? unifiedPlayers[safe: level]?.start(atTime: CHHapticTimeImmediate) }
        }
        return level
    }

    /// 光まで出し終えた時点で呼ぶ。タッチの時刻から何 ms かかったかを記録する
    func recordFired(touchTimestamp: TimeInterval) {
        touchToFireMs = (CACurrentMediaTime() - touchTimestamp) * 1000
    }

    func settingsChanged() {
        buildUnifiedPlayers()
    }

    // MARK: - 音（AVAudioEngine）

    private func startAudio() {
        let session = AVAudioSession.sharedInstance()
        do {
            // 試作ではマナーモードでも鳴らす。本作りで決め直す
            try session.setCategory(.playback, options: [.mixWithOthers])
            try session.setPreferredIOBufferDuration(0.005)
            try session.setActive(true)
        } catch {
            print("AVAudioSession: \(error)")
        }

        let format = AVAudioFormat(standardFormatWithSampleRate: session.sampleRate, channels: 1)!
        buffers = (0..<Self.levelCount).map { ToneSynth.render(level: $0, format: format) }
        audioURLs = buffers.enumerated().compactMap { try? ToneSynth.writeFile($1, name: "tone-\($0)") }

        // 連打で前の音が切れないよう、4つを順番に使う
        audioPlayers = (0..<4).map { _ in AVAudioPlayerNode() }
        for player in audioPlayers {
            audioEngine.attach(player)
            audioEngine.connect(player, to: audioEngine.mainMixerNode, format: format)
        }
        do {
            try audioEngine.start()
            audioPlayers.forEach { $0.play() }
        } catch {
            print("AVAudioEngine: \(error)")
        }
        audioLatencyMs = (session.outputLatency + session.ioBufferDuration) * 1000
    }

    private func playBuffer(_ level: Int) {
        guard audioEngine.isRunning else { return }
        let player = audioPlayers[nextAudioPlayer]
        nextAudioPlayer = (nextAudioPlayer + 1) % audioPlayers.count
        let when = soundDelay > 0
            ? AVAudioTime(hostTime: mach_absolute_time() + AVAudioTime.hostTime(forSeconds: soundDelay))
            : nil
        player.scheduleBuffer(buffers[level], at: when, options: .interrupts)
    }

    // MARK: - 振動（Core Haptics）

    private func startHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            hapticStatus = "この端末は非対応"
            return
        }
        do {
            let engine = try CHHapticEngine(audioSession: .sharedInstance())
            engine.playsHapticsOnly = false
            engine.isAutoShutdownEnabled = false
            engine.resetHandler = { [weak self] in
                Task { @MainActor in self?.restartHaptics() }
            }
            engine.stoppedHandler = { [weak self] reason in
                Task { @MainActor in self?.hapticStatus = "停止（\(reason.rawValue)）" }
            }
            hapticEngine = engine
            restartHaptics()
        } catch {
            hapticStatus = "失敗: \(error.localizedDescription)"
        }
    }

    /// 起動時と、システムがエンジンをリセットしたときに呼ぶ。登録した音とプレイヤーは作り直しになる
    private func restartHaptics() {
        guard let engine = hapticEngine else { return }
        do {
            try engine.start()
            audioResourceIDs = try audioURLs.map { try engine.registerAudioResource($0, options: [:]) }
            hapticPlayers = try (0..<Self.levelCount).map { level in
                try engine.makePlayer(with: CHHapticPattern(events: [Self.hapticEvent(level: level)], parameters: []))
            }
            buildUnifiedPlayers()
            hapticStatus = "動作中"
        } catch {
            hapticStatus = "失敗: \(error.localizedDescription)"
        }
    }

    /// B のパターンは音の遅らせ方と ON/OFF で変わるので、設定を変えるたびに作り直す
    private func buildUnifiedPlayers() {
        guard let engine = hapticEngine, audioResourceIDs.count == Self.levelCount else { return }
        unifiedPlayers = (0..<Self.levelCount).compactMap { level in
            var events: [CHHapticEvent] = []
            if hapticsOn { events.append(Self.hapticEvent(level: level)) }
            if soundOn {
                events.append(CHHapticEvent(
                    audioResourceID: audioResourceIDs[level],
                    parameters: [CHHapticEventParameter(parameterID: .audioVolume, value: 1)],
                    relativeTime: soundDelay))
            }
            if events.isEmpty { events.append(Self.hapticEvent(level: level, intensity: 0)) }
            return try? engine.makePlayer(with: CHHapticPattern(events: events, parameters: []))
        }
    }

    /// 段階が上がるほど強く、鋭くする
    private static func hapticEvent(level: Int, intensity: Float? = nil) -> CHHapticEvent {
        let t = Float(level) / Float(levelCount - 1)
        return CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity ?? 0.55 + 0.45 * t),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.35 + 0.5 * t),
            ],
            relativeTime: 0)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
