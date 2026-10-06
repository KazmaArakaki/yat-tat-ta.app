import AVFoundation

/// 声と効果音。ファイル名は ios/YatTatTa/Sounds/ に置く名前（拡張子は wav か caf）
///
/// ファイルが届くまでは、効果音は合成音で、声は端末の読み上げで代わりに鳴らす。
nonisolated enum Sound: String, CaseIterable, Sendable {
    case voiceChance = "voice_chance"
    case voiceGekiatsu = "voice_gekiatsu"
    case voicePush = "voice_push"
    case voiceYattatta = "voice_yattatta"
    case voiceKakutei1 = "voice_kakutei_1"
    case voiceKakutei2 = "voice_kakutei_2"
    case voiceKakutei3 = "voice_kakutei_3"
    case voiceKakutei4 = "voice_kakutei_4"
    case voiceKakutei5 = "voice_kakutei_5"
    case voiceNegirai1 = "voice_negirai_1"
    case voiceNegirai2 = "voice_negirai_2"
    case voiceNegirai3 = "voice_negirai_3"
    case voiceNegirai4 = "voice_negirai_4"
    case voiceNegirai5 = "voice_negirai_5"
    case voiceToppa = "voice_toppa"
    case voiceFever = "voice_fever"
    case voiceRush = "voice_rush"
    case voiceMilestoneStreak = "voice_milestone_streak"
    case voiceMilestoneDT = "voice_milestone_dt"
    case voiceMilestoneBest = "voice_milestone_best"
    case voiceCombo = "voice_combo"
    case voiceRestart = "voice_restart"
    case fanfare = "sfx_fanfare"
    case coins = "sfx_coins"
    case boom = "sfx_boom"
    case flame = "sfx_flame"
    case bgmHot = "sfx_bgm_hot"
    case bgmMash = "sfx_bgm_mash"
    case bgmFever = "sfx_bgm_fever"

    var isBGM: Bool { self == .bgmHot || self == .bgmMash || self == .bgmFever }

    static func kakutei(_ index: Int) -> Sound {
        [.voiceKakutei1, .voiceKakutei2, .voiceKakutei3, .voiceKakutei4, .voiceKakutei5][index % 5]
    }

    var isVoice: Bool { rawValue.hasPrefix("voice_") }

    /// ファイルがないときに読み上げる言葉
    var spokenFallback: String? {
        switch self {
        case .voiceChance: String(localized: "チャンス！", comment: "声のファイルがないときの読み上げ")
        case .voiceGekiatsu: String(localized: "げきあつ！", comment: "声のファイルがないときの読み上げ")
        case .voicePush: String(localized: "押せ！", comment: "声のファイルがないときの読み上げ")
        case .voiceYattatta: String(localized: "やったった！", comment: "声のファイルがないときの読み上げ")
        case .voiceKakutei1: String(localized: "筋肉、確定！", comment: "声のファイルがないときの読み上げ")
        case .voiceKakutei2: String(localized: "太もも、確定！", comment: "声のファイルがないときの読み上げ")
        case .voiceKakutei3: String(localized: "根性、確定！", comment: "声のファイルがないときの読み上げ")
        case .voiceKakutei4: String(localized: "継続、確定！", comment: "声のファイルがないときの読み上げ")
        case .voiceKakutei5: String(localized: "明日も、確定！", comment: "声のファイルがないときの読み上げ")
        case .voiceNegirai1: String(localized: "今日もお疲れ！", comment: "声のファイルがないときの読み上げ")
        case .voiceNegirai2: String(localized: "夜食のあとに、えらすぎる！", comment: "声のファイルがないときの読み上げ")
        case .voiceNegirai3: String(localized: "あんたはえらい！", comment: "声のファイルがないときの読み上げ")
        case .voiceNegirai4: String(localized: "よっ、ふともも番長！", comment: "声のファイルがないときの読み上げ")
        case .voiceNegirai5: String(localized: "限界突破！", comment: "声のファイルがないときの読み上げ")
        case .voiceToppa: String(localized: "ドパ、突破！", comment: "声のファイルがないときの読み上げ")
        case .voiceFever: String(localized: "フィーバー！", comment: "声のファイルがないときの読み上げ")
        case .voiceRush: String(localized: "ラッシュ！", comment: "声のファイルがないときの読み上げ")
        case .voiceMilestoneStreak: String(localized: "連続記録、達成！", comment: "声のファイルがないときの読み上げ")
        case .voiceMilestoneDT: String(localized: "ドパ、大台突破！", comment: "声のファイルがないときの読み上げ")
        case .voiceMilestoneBest: String(localized: "自己ベスト、更新！", comment: "声のファイルがないときの読み上げ")
        case .voiceCombo: String(localized: "ドパドパ！", comment: "声のファイルがないときの読み上げ")
        case .voiceRestart: String(localized: "今日の1回から！", comment: "声のファイルがないときの読み上げ")
        default: nil
        }
    }

    /// 効果音の長さの上限。届いたファイルが長くても、ここで切って終わりを0.05秒で絞る
    ///
    /// リールが止まる音は0.3秒おきに3回鳴らすので、長いと重なって濁る。回る音は、リールが揃うまでで足りる。
    var maxDuration: TimeInterval? {
        switch self {
        case .fanfare: 3.0
        case .coins: 2.0
        case .boom: 1.2
        case .flame: 1.4
        default: nil
        }
    }

    /// Sounds/ にあるファイルを読む。なければ nil
    ///
    /// 頭と終わりの無音は読むときに切る。叩いた瞬間に鳴らす声は、頭の無音がそのまま遅れになるからです。
    func loadFile(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        for ext in ["wav", "caf"] {
            guard let url = Bundle.main.url(forResource: rawValue, withExtension: ext),
                  let file = try? AVAudioFile(forReading: url),
                  let buffer = Self.convert(file, to: format) else { continue }
            // ループ曲はつなぎ目が変わるので切らない
            return isBGM ? buffer : Self.trim(buffer, maxDuration: maxDuration)
        }
        return nil
    }

    /// いちばん大きい音の3%より小さいところを無音と見て、頭と終わりを切る。頭は10msだけ残す
    static func trim(_ buffer: AVAudioPCMBuffer, maxDuration: TimeInterval?) -> AVAudioPCMBuffer {
        guard let data = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return buffer }
        let n = Int(buffer.frameLength)
        let sampleRate = buffer.format.sampleRate
        var peak: Float = 0
        for i in 0..<n { peak = max(peak, abs(data[i])) }
        let threshold = peak * 0.03
        var head = 0
        while head < n && abs(data[head]) <= threshold { head += 1 }
        var tail = n - 1
        while tail > head && abs(data[tail]) <= threshold { tail -= 1 }
        head = max(0, head - Int(0.01 * sampleRate))
        var length = tail - head + 1
        if let maxDuration { length = min(length, Int(maxDuration * sampleRate)) }
        guard length > 0, let out = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: AVAudioFrameCount(length))
        else { return buffer }
        out.frameLength = AVAudioFrameCount(length)
        let dst = out.floatChannelData![0]
        let fade = min(length, Int(0.05 * sampleRate))
        for i in 0..<length {
            let gain: Float = i >= length - fade ? Float(length - i) / Float(fade) : 1
            dst[i] = data[head + i] * gain
        }
        return out
    }

    /// 合成音の代わり。声は読み上げで代えるので nil
    func synthesized(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        switch self {
        case .fanfare: ToneSynth.fanfare(format: format)
        case .coins: ToneSynth.ticks(format: format, count: 18, interval: 0.07, semitone: 31)
        case .boom: ToneSynth.hot(format: format)
        case .flame: ToneSynth.noise(format: format, duration: 0.8)
        default: nil
        }
    }

    /// 届いたファイルを、エンジンの形式（モノラル、端末のサンプルレート）にそろえる
    private static func convert(_ file: AVAudioFile, to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let source = file.processingFormat
        guard let input = AVAudioPCMBuffer(pcmFormat: source, frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: input)) != nil else { return nil }
        if source.sampleRate == format.sampleRate && source.channelCount == format.channelCount
            && source.commonFormat == format.commonFormat { return input }
        guard let converter = AVAudioConverter(from: source, to: format) else { return nil }
        let capacity = AVAudioFrameCount(Double(input.frameLength) * format.sampleRate / source.sampleRate) + 1024
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
        var fed = false
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if fed {
                status.pointee = .endOfStream
                return nil
            }
            fed = true
            status.pointee = .haveData
            return input
        }
        return error == nil ? output : nil
    }
}
