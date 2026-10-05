import AVFoundation

/// タップ音を合成する。外部の音素材は持たない。
enum ToneSynth {
    /// 段階ごとの音程（ペンタトニック、半音単位）。段階が上がるほど高くなる
    static let semitones: [Double] = [0, 2, 4, 7, 9, 12, 14, 16]
    static let baseFrequency = 523.25 // C5
    static let duration = 0.18

    /// 段階 level の「ポン」を1つ作る。立ち上がり 2ms、減衰の時定数 50ms
    static func render(level: Int, format: AVAudioFormat) -> AVAudioPCMBuffer {
        let sampleRate = format.sampleRate
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        let frequency = baseFrequency * pow(2, semitones[level] / 12)
        let samples = buffer.floatChannelData![0]
        var phase = 0.0
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            // 最初の 15ms で 1.5 倍の高さから落とし、打った感じを出す
            let sweep = 1 + 0.5 * max(0, 1 - t / 0.015)
            phase += 2 * .pi * frequency * sweep / sampleRate
            let attack = min(1, t / 0.002)
            let envelope = attack * exp(-t / 0.05)
            let tone = sin(phase) + 0.3 * sin(2 * phase)
            samples[i] = Float(0.5 * envelope * tone)
        }
        return buffer
    }

    /// Core Haptics に登録するため、音をファイルに書き出す
    static func writeFile(_ buffer: AVAudioPCMBuffer, name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).caf")
        try? FileManager.default.removeItem(at: url)
        let file = try AVAudioFile(forWriting: url, settings: buffer.format.settings)
        try file.write(from: buffer)
        return url
    }
}
