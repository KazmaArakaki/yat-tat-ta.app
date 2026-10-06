import AVFoundation
import CoreHaptics
import os

/// 音の出口まわりのログ。Xcode のコンソールで「[audio]」を探す
private let audioLog = Logger(subsystem: "com.yat-tat-ta", category: "audio")

/// 音と振動を鳴らす
///
/// 音は AVAudioEngine、振動は Core Haptics で別々に鳴らす（手触りの試作の A）。
/// 叩いた瞬間の仕事を減らすため、音も振動のプレイヤーも起動時に作っておく。
final class FeelEngine {
    static let levelCount = ToneSynth.semitones.count

    private let audioEngine = AVAudioEngine()
    /// 叩いた音と効果音の再生口
    private var audioPlayers: [AVAudioPlayerNode] = []
    /// 声だけの再生口。叩いた音に上書きされて、言葉が途中で切れないように分ける
    private var voicePlayers: [AVAudioPlayerNode] = []
    /// 再生口ごとに、いま預けている音
    private var audioSlots: [AudioSlot?] = []
    private var voiceSlots: [AudioSlot?] = []

    private struct AudioSlot {
        let start: TimeInterval
        let end: TimeInterval
        let label: String
        let isVoice: Bool
    }
    private var tapBuffers: [AVAudioPCMBuffer] = []
    private var finaleBuffer: AVAudioPCMBuffer?
    private var milestoneBuffers: [AVAudioPCMBuffer] = []
    private var bassBuffer: AVAudioPCMBuffer?
    private var chanceBuffer: AVAudioPCMBuffer?
    private var wakeBuffer: AVAudioPCMBuffer?
    private var hotBuffer: AVAudioPCMBuffer?
    /// 声と効果音。Sounds/ のファイルか、なければ合成音
    private var sounds: [Sound: AVAudioPCMBuffer] = [:]
    private let loopPlayer = AVAudioPlayerNode()
    /// 再生口をつなぐときの形。出口が変わってつなぎ直すときにも同じものを使う
    private var audioFormat: AVAudioFormat?
    private var configurationObserver: NSObjectProtocol?
    private var routeObserver: NSObjectProtocol?
    private var looping: Sound?
    private var fadeTimer: Timer?
    private var feverTapBuffer: AVAudioPCMBuffer?
    private var feverRushBuffer: AVAudioPCMBuffer?
    /// 声のファイルが届くまでの代わり
    private let speech = AVSpeechSynthesizer()

    private var hapticEngine: CHHapticEngine?
    private var tapHaptics: [CHHapticPatternPlayer] = []
    private var finaleHaptic: CHHapticPatternPlayer?
    private var milestoneHaptic: CHHapticPatternPlayer?
    private var hotHaptic: CHHapticPatternPlayer?
    private var buzzes: [Buzz: CHHapticPatternPlayer] = [:]
    /// スプラッシュの拍。飛ばしたら止めて、残りだけを鳴らし直す
    private var beatPlayer: CHHapticPatternPlayer?

    /// 画面全体の演出に合わせる振動
    enum Buzz: CaseIterable {
        /// リールが止まる
        case reelStop
        /// 金の粒が降るあいだ、細かく震え続ける
        case coins
        /// 確定の文字が落ちる
        case boom
        /// 炎が燃え上がる
        case flame
    }

    func start() {
        startAudio()
        startHaptics()
    }

    /// 1打ぶん。level は進み具合の段階（0〜7）。heavy は激熱から。叩く音に低音を重ねる
    func tap(level: Int, heavy: Bool = false) {
        try? tapHaptics[safe: level]?.start(atTime: CHHapticTimeImmediate)
        play(tapBuffers[safe: level])
        if heavy { play(bassBuffer) }
    }

    /// ドパドパの段階に入った1打。CHANCE は上がる音、激熱は低い音と重い振動
    func enter(_ stage: HypeStage) {
        switch stage {
        case .chance:
            play(chanceBuffer)
            play(.voiceChance)
        case .hot:
            play(hotBuffer)
            play(.voiceGekiatsu)
            try? hotHaptic?.start(atTime: CHHapticTimeImmediate)
            playBGM(.bgmHot)
        case .push:
            play(.voicePush)
        case .normal:
            break
        }
    }

    /// 声か効果音を1つ鳴らす。声のファイルがなければ読み上げで代える
    func play(_ sound: Sound, after delay: TimeInterval = 0) {
        if let buffer = sounds[sound] {
            play(buffer, after: delay, label: sound.rawValue, isVoice: sound.isVoice)
        } else if let text = sound.spokenFallback {
            let utterance = AVSpeechUtterance(string: text)
            // 画面と同じ言語で読む。日本語なら ja-JP、英語なら en-US
            let language = Bundle.main.preferredLocalizations.first == "ja" ? "ja-JP" : "en-US"
            utterance.voice = AVSpeechSynthesisVoice(language: language)
            utterance.rate = 0.56
            utterance.pitchMultiplier = 1.3
            utterance.preUtteranceDelay = delay
            speech.speak(utterance)
        }
    }

    /// ループ曲を鳴らす。最初の1打から鳴らし、激熱とフィーバーで切り替える
    ///
    /// その曲のファイルがなければ、激熱の曲で代える。どれもなければ鳴らさない。
    func playBGM(_ sound: Sound) {
        guard let buffer = sounds[sound] ?? sounds[.bgmHot], audioEngine.isRunning else { return }
        guard looping != sound else { return }
        fadeTimer?.invalidate()
        looping = sound
        loopPlayer.volume = 1
        loopPlayer.scheduleBuffer(buffer, at: nil, options: [.loops, .interrupts])
        loopPlayer.play()
    }

    /// 0.5秒で絞って止める
    func stopBGM() {
        guard looping != nil else { return }
        looping = nil
        fadeTimer?.invalidate()
        var step = 0
        fadeTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self else { return timer.invalidate() }
                step += 1
                self.loopPlayer.volume = max(0, 1 - Float(step) / 10)
                if step >= 10 {
                    timer.invalidate()
                    self.loopPlayer.stop()
                    self.loopPlayer.volume = 1
                }
            }
        }
    }

    // MARK: - フィーバータイム

    func feverStart() {
        playBGM(.bgmFever)
        play(.fanfare)
        play(.voiceFever)
        buzz(.boom)
    }

    /// フィーバーの1打。チャリンと鳴らし、ラッシュでは2つ重ねる
    func feverTap(rush: Bool) {
        try? tapHaptics.last?.start(atTime: CHHapticTimeImmediate)
        play(feverTapBuffer)
        if rush { play(feverRushBuffer) }
    }

    func feverEnd() {
        play(.fanfare)
        buzz(.coins)
    }

    /// ドパ突破。ドーンとファンファーレ、金なら声も節目のものにする
    func toppa(gold: Bool) {
        buzz(.boom)
        play(.boom)
        play(.fanfare, after: 0.05)
        play(gold ? .voiceMilestoneDT : .voiceToppa, after: 0.1)
    }

    func buzz(_ buzz: Buzz, after delay: TimeInterval = 0) {
        guard let engine = hapticEngine else { return }
        try? buzzes[buzz]?.start(atTime: delay > 0 ? engine.currentTime + delay : CHHapticTimeImmediate)
    }

    /// 声の長さ。ファイルがなければ、読み上げのおおよその長さ
    func duration(_ sound: Sound) -> TimeInterval {
        guard let buffer = sounds[sound] else { return sound.isVoice ? 1.2 : 0 }
        return Double(buffer.frameLength) / buffer.format.sampleRate
    }

    /// 叩き切ったあとの声の並び。声が重ならないよう、届いたファイルの長さから決める
    struct FinaleTiming: Equatable {
        /// 確定の声を鳴らす時刻（やったったの声のあと）
        let kakuteiVoiceAt: TimeInterval
        /// 確定を見せる長さ。ここでねぎらいに切り替わる
        let kakutei: TimeInterval
        /// ねぎらいを見せる長さ
        let negirai: TimeInterval
    }

    func finaleTiming(kakutei: Int, negirai: Sound) -> FinaleTiming {
        let kakuteiVoiceAt = duration(.voiceYattatta) + 0.05
        return FinaleTiming(
            kakuteiVoiceAt: kakuteiVoiceAt,
            kakutei: max(1.4, kakuteiVoiceAt + duration(.kakutei(kakutei)) + 0.15),
            negirai: max(1.8, duration(negirai) + 0.4))
    }

    /// 叩き切ったあと。確定（ドーン、やったった、確定の声）、ねぎらい（炎、ねぎらいの声）、節目の札の順
    func finale(kakutei: Int, negirai: Sound, milestones: [Milestone], timing: FinaleTiming, after delay: TimeInterval) {
        buzz(.boom, after: delay)
        play(.boom, after: delay)
        play(.voiceYattatta, after: delay)
        play(.kakutei(kakutei), after: delay + timing.kakuteiVoiceAt)
        let negiraiAt = delay + timing.kakutei
        buzz(.flame, after: negiraiAt)
        play(.flame, after: negiraiAt)
        play(finaleBuffer, after: negiraiAt)
        play(negirai, after: negiraiAt + 0.2)
        let tagsAt = negiraiAt + timing.negirai
        for (i, m) in milestones.enumerated() {
            let t = tagsAt + 0.3 * Double(i)
            play(milestoneBuffers[safe: i], after: t)
            if let engine = hapticEngine { try? milestoneHaptic?.start(atTime: engine.currentTime + t) }
        }
        if let first = milestones.first { play(Self.voice(for: first), after: tagsAt + 0.1) }
    }

    private static func voice(for milestone: Milestone) -> Sound {
        switch milestone {
        case .streak: .voiceMilestoneStreak
        case .dopaTotal: .voiceMilestoneDT
        case .bestWindow: .voiceMilestoneBest
        }
    }

    /// スクワット隊に1人増えた。高い音とトンという振動
    func recruit() {
        play(milestoneBuffers[safe: 1])
        buzz(.reelStop)
    }

    /// 寝ていた隊が起きた。指を離す前に、もう叩けると分かるように
    func wake() {
        play(wakeBuffer)
        buzz(.reelStop)
    }

    /// スプラッシュの拍。at 秒後に、軽い振動か（strong なら）中くらいの振動。音は出さない
    ///
    /// 絵と振動がずれないよう、1つの模様にまとめて鳴らす。呼ぶたびに、前の模様の残りは止める。
    struct Beat: Equatable {
        let at: TimeInterval
        let strong: Bool
    }

    func beats(_ beats: [Beat]) {
        try? beatPlayer?.stop(atTime: CHHapticTimeImmediate)
        beatPlayer = nil
        guard let engine = hapticEngine, !beats.isEmpty else { return }
        let events = beats.map { beat in
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                .init(parameterID: .hapticIntensity, value: beat.strong ? 0.8 : 0.45),
                .init(parameterID: .hapticSharpness, value: beat.strong ? 0.6 : 0.4),
            ], relativeTime: max(0, beat.at))
        }
        do {
            let player = try engine.makePlayer(with: CHHapticPattern(events: events, parameters: []))
            try player.start(atTime: CHHapticTimeImmediate)
            beatPlayer = player
        } catch {
            print("CHHapticEngine: \(error)")
        }
    }

    /// 連打の途中でまたいだ節目。札1枚ぶん
    func milestone() {
        try? milestoneHaptic?.start(atTime: CHHapticTimeImmediate)
        play(milestoneBuffers.first)
    }

    // MARK: - 音

    private func startAudio() {
        let session = AVAudioSession.sharedInstance()
        do {
            // マナーモードでは鳴らさない。ほかのアプリの音も止めない
            try session.setCategory(.ambient, options: [.mixWithOthers])
            try session.setPreferredIOBufferDuration(0.005)
            try session.setActive(true)
        } catch {
            print("AVAudioSession: \(error)")
        }

        let format = AVAudioFormat(standardFormatWithSampleRate: session.sampleRate, channels: 1)!
        tapBuffers = (0..<Self.levelCount).map { ToneSynth.tap(level: $0, format: format) }
        finaleBuffer = ToneSynth.finale(format: format)
        milestoneBuffers = (0..<4).map { ToneSynth.milestone(index: $0, format: format) }
        // 27個のファイルを読んで変換すると起動が止まるので、裏で読む。届くまでの声は読み上げで代わる
        Task.detached(priority: .userInitiated) { [weak self] in
            let loaded = LoadedSounds(Sound.allCases.reduce(into: [:]) { result, sound in
                if let buffer = sound.loadFile(format: format) ?? sound.synthesized(format: format) {
                    result[sound] = buffer
                }
            })
            await MainActor.run { self?.sounds = loaded.value }
        }
        feverTapBuffer = ToneSynth.ticks(format: format, count: 2, interval: 0.04, semitone: 31)
        feverRushBuffer = ToneSynth.ticks(format: format, count: 2, interval: 0.04, semitone: 36)
        audioEngine.attach(loopPlayer)
        audioEngine.connect(loopPlayer, to: audioEngine.mainMixerNode, format: format)
        bassBuffer = ToneSynth.bass(format: format)
        chanceBuffer = ToneSynth.chance(format: format)
        wakeBuffer = ToneSynth.wake(format: format)
        hotBuffer = ToneSynth.hot(format: format)

        // 連打で前の音が切れないよう、空いている再生口を使う。低音、段階の音、フィナーレ、札の音が重なる分も含む
        audioPlayers = (0..<8).map { _ in AVAudioPlayerNode() }
        // フィナーレは声を4つ先に預けるので、その間に鳴る10打ごとの声や段階の声の分も足して6つ
        voicePlayers = (0..<6).map { _ in AVAudioPlayerNode() }
        audioSlots = Array(repeating: nil, count: audioPlayers.count)
        voiceSlots = Array(repeating: nil, count: voicePlayers.count)
        for player in audioPlayers + voicePlayers {
            audioEngine.attach(player)
            audioEngine.connect(player, to: audioEngine.mainMixerNode, format: format)
        }
        audioFormat = format
        logAudio("start")
        routeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main
        ) { [weak self] note in
            let reason = (note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt) ?? 0
            MainActor.assumeIsolated { self?.logAudio("route change reason=\(reason)") }
        }
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: audioEngine, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reconnectAudio() }
        }
        do {
            try audioEngine.start()
            (audioPlayers + voicePlayers).forEach { $0.play() }
        } catch {
            print("AVAudioEngine: \(error)")
        }
    }

    /// 音の出口が変わったとき（AirPods をつないだ、外した）
    ///
    /// iOS は出口の形（サンプリングの速さ）が変わると、音の仕組みを止め、再生口と出口のつながりも切る。
    /// 動かし直すだけでは音が出口に届かないので、全部の再生口をつなぎ直してから動かす。
    /// 預けていた音は消えているので、再生口の空きも消しておく。ループ曲は頭から鳴らし直す。
    private func reconnectAudio() {
        logAudio("configuration change")
        defer { logAudio("reconnected") }
        guard let format = audioFormat else { return }
        audioEngine.stop()
        for player in [loopPlayer] + audioPlayers + voicePlayers {
            audioEngine.disconnectNodeOutput(player)
            audioEngine.connect(player, to: audioEngine.mainMixerNode, format: format)
        }
        audioSlots = Array(repeating: nil, count: audioPlayers.count)
        voiceSlots = Array(repeating: nil, count: voicePlayers.count)
        do {
            try audioEngine.start()
            (audioPlayers + voicePlayers).forEach { $0.play() }
        } catch {
            print("AVAudioEngine: \(error)")
        }
        if let sound = looping {
            looping = nil
            playBGM(sound)
        }
    }

    private func play(_ buffer: AVAudioPCMBuffer?, after delay: TimeInterval = 0,
                      label: String = "tone", isVoice: Bool = false) {
        guard let buffer else { return }
        if !audioEngine.isRunning {
            // 電話などで止まったエンジンは、次の1打で起こす
            logAudio("engine stopped at play")
            try? audioEngine.start()
            (audioPlayers + voicePlayers).forEach { $0.play() }
        }
        guard audioEngine.isRunning else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let start = now + delay
        let slot = AudioSlot(start: start, end: start + Double(buffer.frameLength) / buffer.format.sampleRate,
                             label: label, isVoice: isVoice)
        let player: AVAudioPlayerNode
        if isVoice {
            let i = Self.pickSlot(voiceSlots, now: now)
            noteCut(voiceSlots[i], now: now)
            voiceSlots[i] = slot
            player = voicePlayers[i]
        } else {
            let i = Self.pickSlot(audioSlots, now: now)
            noteCut(audioSlots[i], now: now)
            audioSlots[i] = slot
            player = audioPlayers[i]
        }
        let when = delay > 0
            ? AVAudioTime(hostTime: mach_absolute_time() + AVAudioTime.hostTime(forSeconds: delay))
            : nil
        player.scheduleBuffer(buffer, at: when, options: .interrupts)
    }

    /// 音の出口と、音の仕組みの状態を書き出す
    private func logAudio(_ event: String) {
        let session = AVAudioSession.sharedInstance()
        // 出口の名前（「〇〇の AirPods」）には持ち主の名前が入ることがあるので、種類だけを出す
        let outputs = session.currentRoute.outputs.map(\.portType.rawValue).joined(separator: ",")
        let hardware = audioEngine.outputNode.outputFormat(forBus: 0)
        audioLog.notice("""
            [audio] \(event, privacy: .public) running=\(self.audioEngine.isRunning) \
            session=\(session.sampleRate)Hz category=\(session.category.rawValue, privacy: .public) \
            out=\(outputs, privacy: .public) hw=\(hardware.sampleRate)Hz/\(hardware.channelCount)ch \
            volume=\(session.outputVolume) otherAudio=\(session.isOtherAudioPlaying)
            """)
    }

    /// 預ける再生口を選ぶ。.interrupts で預けると、その再生口で鳴っている音も、これから鳴る予定の音も消える
    ///
    /// 鳴り終えた再生口があればそこを使う。なければ、いちばん早く鳴り終わる音を切る。
    private static func pickSlot(_ slots: [AudioSlot?], now: TimeInterval) -> Int {
        if let free = slots.firstIndex(where: { ($0?.end ?? 0) <= now }) { return free }
        return slots.indices.min { slots[$0]!.end < slots[$1]!.end }!
    }

    /// 計測モードで、鳴り終わる前に上書きした音を数える
    private func noteCut(_ slot: AudioSlot?, now: TimeInterval) {
        #if DEBUG
        guard let monitor = PerfMonitor.shared, let slot, slot.end > now else { return }
        monitor.soundCut(.init(label: slot.label, isVoice: slot.isVoice, left: slot.end - now, started: now >= slot.start))
        #endif
    }

    // MARK: - 振動

    private func startHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let engine = try CHHapticEngine()
            engine.isAutoShutdownEnabled = false
            engine.resetHandler = { [weak self] in
                Task { @MainActor in self?.restartHaptics() }
            }
            hapticEngine = engine
            restartHaptics()
        } catch {
            print("CHHapticEngine: \(error)")
        }
    }

    /// 起動時と、システムがエンジンをリセットしたときに呼ぶ。プレイヤーは作り直しになる
    private func restartHaptics() {
        guard let engine = hapticEngine else { return }
        do {
            try engine.start()
            tapHaptics = try (0..<Self.levelCount).map { level in
                try engine.makePlayer(with: CHHapticPattern(events: [Self.tapEvent(level: level)], parameters: []))
            }
            finaleHaptic = try engine.makePlayer(with: CHHapticPattern(events: [
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    .init(parameterID: .hapticIntensity, value: 1),
                    .init(parameterID: .hapticSharpness, value: 0.9),
                ], relativeTime: 0),
                CHHapticEvent(eventType: .hapticContinuous, parameters: [
                    .init(parameterID: .hapticIntensity, value: 0.7),
                    .init(parameterID: .hapticSharpness, value: 0.3),
                ], relativeTime: 0.02, duration: 0.35),
            ], parameters: []))
            hotHaptic = try engine.makePlayer(with: CHHapticPattern(events: [
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    .init(parameterID: .hapticIntensity, value: 1),
                    .init(parameterID: .hapticSharpness, value: 0.2),
                ], relativeTime: 0),
                CHHapticEvent(eventType: .hapticContinuous, parameters: [
                    .init(parameterID: .hapticIntensity, value: 0.9),
                    .init(parameterID: .hapticSharpness, value: 0.1),
                ], relativeTime: 0.01, duration: 0.25),
            ], parameters: []))
            buzzes = try Dictionary(uniqueKeysWithValues: Buzz.allCases.map { buzz in
                (buzz, try engine.makePlayer(with: CHHapticPattern(events: Self.events(for: buzz), parameters: [])))
            })
            milestoneHaptic = try engine.makePlayer(with: CHHapticPattern(events: [
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    .init(parameterID: .hapticIntensity, value: 1),
                    .init(parameterID: .hapticSharpness, value: 1),
                ], relativeTime: 0),
            ], parameters: []))
        } catch {
            print("CHHapticEngine: \(error)")
        }
    }

    private static func events(for buzz: Buzz) -> [CHHapticEvent] {
        func transient(_ t: TimeInterval, _ intensity: Float, _ sharpness: Float) -> CHHapticEvent {
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                .init(parameterID: .hapticIntensity, value: intensity),
                .init(parameterID: .hapticSharpness, value: sharpness),
            ], relativeTime: t)
        }
        func continuous(_ t: TimeInterval, _ d: TimeInterval, _ intensity: Float, _ sharpness: Float) -> CHHapticEvent {
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                .init(parameterID: .hapticIntensity, value: intensity),
                .init(parameterID: .hapticSharpness, value: sharpness),
            ], relativeTime: t, duration: d)
        }
        switch buzz {
        case .reelStop:
            return [transient(0, 1, 0.6)]
        case .coins:
            return (0..<20).map { transient(Double($0) * 0.05, .random(in: 0.4...0.8), .random(in: 0.7...1)) }
        case .boom:
            return [transient(0, 1, 0.1), continuous(0.01, 0.45, 1, 0.05)]
        case .flame:
            return [continuous(0, 0.8, 0.6, 0.2)]
        }
    }

    /// 段階が上がるほど強く、鋭くする
    private static func tapEvent(level: Int) -> CHHapticEvent {
        let t = Float(level) / Float(levelCount - 1)
        return CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.55 + 0.45 * t),
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

/// 裏で読んだ音を、メインスレッドへ渡すための入れ物。渡したあとは読むだけで書き換えない
private final class LoadedSounds: @unchecked Sendable {
    let value: [Sound: AVAudioPCMBuffer]
    init(_ value: [Sound: AVAudioPCMBuffer]) { self.value = value }
}
