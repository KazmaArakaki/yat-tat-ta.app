import SwiftUI

/// 手触りの試作画面。タップ→音→振動→光のずれを、実機で確かめる
struct FeelPrototypeView: View {
    @State private var engine = FeelEngine()

    private let pink = Color(red: 0.90, green: 0.20, blue: 0.48)
    private let paper = Color(red: 0.98, green: 0.96, blue: 0.93)

    var body: some View {
        VStack(spacing: 14) {
            readouts
            ZStack {
                FeelPadView(engine: engine)
                Text("TAP")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundStyle(paper.opacity(0.25))
                    .allowsHitTesting(false)
            }
            controls
        }
        .padding(16)
        .background(Color(red: 0.07, green: 0.06, blue: 0.07).ignoresSafeArea())
        .foregroundStyle(paper)
        .preferredColorScheme(.dark)
        .onAppear { engine.start() }
        .onChange(of: engine.soundOn) { engine.settingsChanged() }
        .onChange(of: engine.hapticsOn) { engine.settingsChanged() }
        .onChange(of: engine.soundDelay) { engine.settingsChanged() }
    }

    private var readouts: some View {
        HStack(alignment: .top) {
            readout("段階", "\(engine.level + 1) / \(FeelEngine.levelCount)")
            readout("タッチ→発火", engine.touchToFireMs.map { String(format: "%.1f ms", $0) } ?? "—")
            readout("音の出力遅延", String(format: "%.1f ms", engine.audioLatencyMs))
            readout("振動", engine.hapticStatus)
        }
    }

    private func readout(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(paper.opacity(0.55))
            Text(value).font(.system(.footnote, design: .monospaced).weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var controls: some View {
        @Bindable var engine = engine
        return VStack(spacing: 12) {
            HStack(spacing: 8) {
                chip("音", isOn: $engine.soundOn)
                chip("振動", isOn: $engine.hapticsOn)
                chip("光", isOn: $engine.lightOn)
            }
            Picker("鳴らし方", selection: $engine.mode) {
                ForEach(SyncMode.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            VStack(alignment: .leading, spacing: 4) {
                Text("音をわざと遅らせる  \(Int(engine.soundDelay * 1000)) ms")
                    .font(.system(.footnote, design: .monospaced))
                Slider(value: $engine.soundDelay, in: 0...0.15, step: 0.01)
                    .tint(pink)
            }
        }
    }

    private func chip(_ title: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            Text(title)
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isOn.wrappedValue ? pink : paper.opacity(0.08), in: .capsule)
                .foregroundStyle(isOn.wrappedValue ? paper : paper.opacity(0.5))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    FeelPrototypeView()
}
