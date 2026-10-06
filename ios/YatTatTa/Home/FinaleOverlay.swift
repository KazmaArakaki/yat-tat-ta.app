import SwiftUI

/// 叩き切ったあとの演出。確定（見本2）、ねぎらい（見本3）、節目の札の順に出す
///
/// 途中で閉じた記録では、確定とねぎらいを出さず、札だけを出す。
/// 叩き切って1.2秒が過ぎたら、触って飛ばせる。
struct FinaleOverlay: View {
    let event: FinaleEvent
    let skip: () -> Void

    @State private var phase = Phase.kakutei
    @State private var flash = 1.0
    @State private var landed = false
    @State private var skippable = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Phase { case kakutei, negirai }

    var body: some View {
        Group {
            if event.completed, let negirai = event.negirai {
                ZStack {
                    switch phase {
                    case .kakutei: kakutei
                    case .negirai: negiraiView(negirai)
                    }
                    Color.white.opacity(flash).allowsHitTesting(false)
                }
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { if skippable { skip() } }
                .allowsHitTesting(skippable)
                .task { await run() }
            } else {
                tags
                    .padding(24)
                    .allowsHitTesting(false)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// 見本で、確定を飛ばしてねぎらいから出す
    var startAtNegirai = false

    private func run() async {
        if startAtNegirai {
            flash = 0
            phase = .negirai
            withAnimation(.spring(duration: 0.4, bounce: 0.5)) { landed = true }
            skippable = true
            return
        }
        // 白い閃光は1回だけ。明滅の上限（1秒3回）に触れない
        withAnimation(.easeOut(duration: 0.25)) { flash = 0 }
        withAnimation(reduceMotion ? nil : .spring(duration: 0.35, bounce: 0.45)) { landed = true }
        try? await Task.sleep(for: .seconds(FinaleEvent.skippableAfter))
        skippable = true
        try? await Task.sleep(for: .seconds(event.kakuteiDuration - FinaleEvent.skippableAfter))
        landed = false
        withAnimation(.easeOut(duration: 0.2)) { phase = .negirai }
        withAnimation(reduceMotion ? nil : .spring(duration: 0.4, bounce: 0.5)) { landed = true }
    }

    /// 確定。虹の放射線の上に、金属の文字が2行でドンと落ちる
    private var kakutei: some View {
        let words = FinaleEvent.kakuteiWords[event.kakutei % FinaleEvent.kakuteiWords.count]
        return ZStack {
            Color.black
            RaysView(palette: .rainbow, period: 2)
            ParticlesView(kind: .sparks)
            Shockwave(color: .white, lineWidth: 34)
            VStack(spacing: -10) {
                MetalText(text: words.0, size: words.0.count > 2 ? 104 : 140)
                MetalText(text: words.1, size: 140)
                HStack(spacing: 10) {
                    Text("やったった！").font(.label(22, black: true))
                    Text("+\(event.reps) ドパ").font(.number(22))
                }
                .foregroundStyle(.white)
                .shadow(color: .black, radius: 0, x: 2, y: 2)
                .padding(.top, 24)
            }
            .scaleEffect(landed ? 1 : 3)
            .opacity(landed ? 1 : 0)
            .rotationEffect(.degrees(landed || reduceMotion ? -3 : -12))
        }
    }

    /// ねぎらい。金の炎の中に、金の文字
    private func negiraiView(_ negirai: Negirai) -> some View {
        ZStack {
            GoldFlame()
            RaysView(palette: .gold, period: 3).opacity(0.6)
            Shockwave(color: .gold, lineWidth: 30)
            ParticlesView(kind: .sparks)
            ParticlesView(kind: .embers)
            VStack(spacing: 6) {
                if let headline = negirai.headline {
                    MetalText(text: headline, size: Self.fit(headline, max: 64), finish: .dopa)
                }
                // 長い言葉は「、」で2行に分け、画面の幅に収まる大きさにする
                let lines = Self.lines(negirai.message)
                ForEach(lines, id: \.self) { line in
                    MetalText(text: line, size: Self.fit(lines.max { $0.count < $1.count } ?? line, max: 96), finish: .gold)
                }
                tags.padding(.top, 20)
            }
            .padding(.horizontal, 12)
            .scaleEffect(landed ? 1 : 0.3)
            .opacity(landed ? 1 : 0)
        }
    }

    private static func lines(_ message: String) -> [String] {
        guard message.count > 8, let comma = message.firstIndex(of: "、") else { return [message] }
        return [String(message[...comma]), String(message[message.index(after: comma)...])]
    }

    /// 1文字ぶんの幅を文字の大きさとほぼ同じと見て、縁取りの分を引いた幅 320pt に収める
    private static func fit(_ text: String, max: CGFloat) -> CGFloat {
        min(max, 320 / CGFloat(Swift.max(text.count, 1)))
    }

    private var tags: some View {
        VStack(spacing: 10) {
            ForEach(Array(event.milestones.enumerated()), id: \.offset) { i, m in
                MilestoneTag(milestone: m)
                    .opacity(landed || !event.completed ? 1 : 0)
                    .animation(.spring(duration: 0.35, bounce: 0.5).delay(0.3 * Double(i)), value: landed)
            }
        }
    }
}

/// 金の炎。重ねた光の玉を、ゆっくり揺らす
private struct GoldFlame: View {
    @State private var flicker = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            RadialGradient(colors: [Color(hex: 0xFFF3B0), Color(hex: 0xFFB000), Color(hex: 0xB34700), Color(hex: 0x2A0E00)],
                           center: .center, startRadius: 10, endRadius: 520)
            ForEach(0..<6, id: \.self) { i in
                Ellipse()
                    .fill(Color(hex: ([0xFFD23F, 0xFF8A00, 0xFFF3B0] as [UInt32])[i % 3]).opacity(0.55))
                    .frame(width: 220, height: 420)
                    .blur(radius: 50)
                    .offset(x: CGFloat(i - 3) * 70, y: flicker ? -60 : 40)
                    .scaleEffect(flicker ? 1.15 : 0.9)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.35 + 0.07 * Double(i))
                        .repeatForever(autoreverses: true), value: flicker)
            }
        }
        .onAppear { flicker = true }
    }
}

/// 節目の札
struct MilestoneTag: View {
    let milestone: Milestone

    var body: some View {
        Text(title)
            .font(.label(17, black: true))
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(Color.gold, in: .capsule)
            .overlay(Capsule().strokeBorder(Color.ink, lineWidth: 2))
            .foregroundStyle(Color.onGold)
    }

    private var title: LocalizedStringKey {
        switch milestone {
        case .dopaTotal(let n): "DT \(n.formatted()) ドパ"
        case .streak(let n): "連続 \(n) 日"
        case .bestWindow: "DPW 自己ベスト"
        }
    }
}
