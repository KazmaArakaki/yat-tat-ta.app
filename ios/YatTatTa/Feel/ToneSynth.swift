import AVFoundation

/// 音を合成する。外部の音素材は持たない。
nonisolated enum ToneSynth {
    /// 段階ごとの音程（ペンタトニック、半音単位）。段階が上がるほど高くなる
    static let semitones: [Double] = [0, 2, 4, 7, 9, 12, 14, 16]
    static let baseFrequency = 523.25 // C5

    /// 段階 level の「ポン」を1つ作る。立ち上がり 2ms、減衰の時定数 50ms
    static func tap(level: Int, format: AVAudioFormat) -> AVAudioPCMBuffer {
        render(format: format, duration: 0.18, decay: 0.05, gain: 0.5, frequencies: [frequency(semitones[level])])
    }

    /// フィナーレの和音。最後の段階の音に、5度と1オクターブ上を重ねて長めに鳴らす
    static func finale(format: AVAudioFormat) -> AVAudioPCMBuffer {
        let top = semitones[semitones.count - 1]
        return render(format: format, duration: 0.9, decay: 0.28, gain: 0.32,
                      frequencies: [top - 12, top - 5, top, top + 7].map(frequency))
    }

    /// 節目の札1枚ぶんの音。札が増えるほど高くする
    static func milestone(index: Int, format: AVAudioFormat) -> AVAudioPCMBuffer {
        let semitone = semitones[semitones.count - 1] + 12 + [0, 4, 7, 12][min(index, 3)]
        return render(format: format, duration: 0.35, decay: 0.1, gain: 0.35, frequencies: [frequency(semitone)])
    }

    /// 寝ていたスクワット隊が起きた。低い音から跳ね上がる「ぴょこっ」
    static func wake(format: AVAudioFormat) -> AVAudioPCMBuffer {
        sequence(format: format, semitones: [-5, 7], step: 0.07, decay: 0.06, gain: 0.4)
    }

    /// 激熱からの1打に重ねる低音
    static func bass(format: AVAudioFormat) -> AVAudioPCMBuffer {
        render(format: format, duration: 0.16, decay: 0.05, gain: 0.45, frequencies: [-24].map(frequency))
    }

    /// CHANCE に入った1打。3音で駆け上がる
    static func chance(format: AVAudioFormat) -> AVAudioPCMBuffer {
        sequence(format: format, semitones: [7, 12, 19], step: 0.06, decay: 0.08, gain: 0.35)
    }

    /// 激熱に入った1打。低い音を3つ重ねてドンと鳴らす
    static func hot(format: AVAudioFormat) -> AVAudioPCMBuffer {
        render(format: format, duration: 0.6, decay: 0.18, gain: 0.5, frequencies: [-29, -24, -17].map(frequency))
    }

    /// 短い高い音を count 回並べる。リールの回転やジャラジャラの代わり
    static func ticks(format: AVAudioFormat, count: Int, interval: Double, semitone: Double) -> AVAudioPCMBuffer {
        let tones = (0..<count).map { semitone + Double([0, 5, 2, 7][$0 % 4]) }
        return sequence(format: format, semitones: tones, step: interval, decay: 0.02, gain: 0.25)
    }

    /// 揃ったときのファンファーレの代わり。ドミソドを駆け上がって伸ばす
    static func fanfare(format: AVAudioFormat) -> AVAudioPCMBuffer {
        sequence(format: format, semitones: [0, 4, 7, 12, 16, 19, 24], step: 0.09, decay: 0.3, gain: 0.3)
    }

    /// 炎の「ゴォッ」の代わり。ゆっくり立ち上がって消える雑音
    static func noise(format: AVAudioFormat, duration: Double) -> AVAudioPCMBuffer {
        let sampleRate = format.sampleRate
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let out = buffer.floatChannelData![0]
        var low: Float = 0
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let envelope = Float(min(1, t / 0.15) * exp(-max(0, t - 0.15) / 0.25))
            // 高い成分を削って、こもった音にする
            low += 0.08 * (Float.random(in: -1...1) - low)
            out[i] = 0.9 * envelope * low
        }
        return buffer
    }

    /// 音を step 秒ずつずらして並べる
    private static func sequence(format: AVAudioFormat, semitones: [Double], step: Double, decay: Double,
                                 gain: Double) -> AVAudioPCMBuffer {
        let length = max(0.3, decay * 4)
        let parts = semitones.map { render(format: format, duration: length, decay: decay, gain: gain, frequencies: [frequency($0)]) }
        let sampleRate = format.sampleRate
        let offset = Int(step * sampleRate)
        let frameCount = AVAudioFrameCount(offset * (parts.count - 1) + Int(parts[0].frameLength))
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let out = buffer.floatChannelData![0]
        for i in 0..<Int(frameCount) { out[i] = 0 }
        for (k, part) in parts.enumerated() {
            let src = part.floatChannelData![0]
            for i in 0..<Int(part.frameLength) { out[k * offset + i] += src[i] }
        }
        return buffer
    }

    private static func frequency(_ semitone: Double) -> Double {
        baseFrequency * pow(2, semitone / 12)
    }

    private static func render(format: AVAudioFormat, duration: Double, decay: Double, gain: Double,
                               frequencies: [Double]) -> AVAudioPCMBuffer {
        let sampleRate = format.sampleRate
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        let samples = buffer.floatChannelData![0]
        var phases = [Double](repeating: 0, count: frequencies.count)
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            // 最初の 15ms で 1.5 倍の高さから落とし、打った感じを出す
            let sweep = 1 + 0.5 * max(0, 1 - t / 0.015)
            var tone = 0.0
            for (k, f) in frequencies.enumerated() {
                phases[k] += 2 * .pi * f * sweep / sampleRate
                tone += sin(phases[k]) + 0.3 * sin(2 * phases[k])
            }
            let attack = min(1, t / 0.002)
            let envelope = attack * exp(-t / decay)
            samples[i] = Float(gain * envelope * tone / Double(frequencies.count).squareRoot())
        }
        return buffer
    }
}
