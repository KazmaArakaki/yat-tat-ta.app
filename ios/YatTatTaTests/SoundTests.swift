import AVFoundation
import Testing
@testable import YatTatTa

struct SoundTests {
    private let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)!

    @Test func 置いた声と効果音はすべて読める() {
        let placed = Sound.allCases.filter { s in
            ["wav", "caf"].contains { Bundle.main.url(forResource: s.rawValue, withExtension: $0) != nil }
        }
        #expect(!placed.isEmpty)
        let broken = placed.filter { $0.loadFile(format: format) == nil }
        #expect(broken.isEmpty, "読めないファイル: \(broken.map(\.rawValue))")
    }

    @Test func 声の頭の無音は読むときに切られる() throws {
        for sound in Sound.allCases where sound.isVoice {
            guard let buffer = sound.loadFile(format: format) else { continue }
            let data = buffer.floatChannelData![0]
            var peak: Float = 0
            for i in 0..<Int(buffer.frameLength) { peak = max(peak, abs(data[i])) }
            var head = 0
            while head < Int(buffer.frameLength) && abs(data[head]) <= peak * 0.03 { head += 1 }
            // 残すのは 10ms まで
            #expect(Double(head) / format.sampleRate <= 0.011, "\(sound.rawValue) の頭に \(head) サンプルの無音")
        }
    }

    @Test func 効果音は上限の長さで切られる() throws {
        for sound in Sound.allCases {
            guard let max = sound.maxDuration, let buffer = sound.loadFile(format: format) else { continue }
            #expect(Double(buffer.frameLength) / format.sampleRate <= max + 0.001)
        }
    }
}
