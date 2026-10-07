import SwiftUI

/// チュートリアルの案内。ホームに暗い幕をかけ、1か所だけを照らして、吹き出しで言う
///
/// 照らした穴は触れても幕に当たらず、下の画面に届く。起こすと練習連打は、そこを叩いてもらう。
/// 叩けば進む場面では、幕のどこを叩いても次へ進む（照らした帯やカードを押しても開かない）。
struct TutorialOverlay: View {
    let step: TutorialStep
    /// 照らす場所の位置（画面全体の座標）。HomeView が測って渡す
    let frames: [TutorialTarget: CGRect]
    let targetReps: Int
    /// 記録がまだ1件もない人か。おわりの一言を変える
    let firstTime: Bool
    let advance: () -> Void
    let end: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        GeometryReader { geo in
            let origin = geo.frame(in: .global).origin
            let hole = hole(origin: origin)
            ZStack(alignment: .top) {
                scrim(size: geo.size, hole: hole)
                if let hole {
                    ring(hole)
                }
                bubbleArea(size: geo.size, hole: hole, safe: geo.safeAreaInsets)
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.45), value: step)
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { pulse = true }
        }
        .onChange(of: step, initial: true) {
            AccessibilityNotification.Announcement(String(localized: title) + " " + String(localized: message)).post()
        }
    }

    // MARK: - 幕と穴

    private func hole(origin: CGPoint) -> CGRect? {
        guard let target = step.target, let frame = frames[target] else { return nil }
        // 叩く場所はもとから広く、上下にすき間がない。広げるとカードにかかる
        let pad: CGFloat = switch target { case .stage: 0; case .gear: 4; default: 8 }
        return frame.offsetBy(dx: -origin.x, dy: -origin.y).insetBy(dx: -pad, dy: -pad)
    }

    private func holePath(_ hole: CGRect) -> Path {
        step.target == .gear ? Path(ellipseIn: hole) : Path(roundedRect: hole, cornerRadius: 22)
    }

    /// 穴をあけた幕。穴の中は当たり判定からも抜き、下の画面に触れられるようにする
    private func scrim(size: CGSize, hole: CGRect?) -> some View {
        var path = Path(CGRect(origin: .zero, size: size))
        if let hole { path.addPath(holePath(hole)) }
        return path
            .fill(Color.black.opacity(0.62), style: FillStyle(eoFill: true))
            .contentShape(path, eoFill: true)
            .onTapGesture { if step.advancesByTap { advance() } }
            .accessibilityHidden(true)
    }

    /// 照らした場所のまわりの金の点線。ゆっくり濃淡を繰り返す
    private func ring(_ hole: CGRect) -> some View {
        holePath(hole.insetBy(dx: -3, dy: -3))
            .stroke(Color.gold, style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
            .opacity(reduceMotion ? 1 : pulse ? 1 : 0.35)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    // MARK: - 吹き出し

    /// 叩く場所を照らすときは下のカードの上に、帯と歯車は下に、カードは上に置く
    @ViewBuilder private func bubbleArea(size: CGSize, hole: CGRect?, safe: EdgeInsets) -> some View {
        if step == .finish {
            finishCard
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                switch step.target {
                case .streak?, .gear?:
                    Spacer().frame(height: (hole?.maxY ?? 0) + 12)
                    bubble
                    Spacer(minLength: 0)
                case .totals?:
                    Spacer(minLength: 0)
                    bubble
                    Spacer().frame(height: size.height - (hole?.minY ?? size.height) + 12)
                default:
                    Spacer(minLength: 0)
                    bubble
                    Spacer().frame(height: safe.bottom + 12)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                dots
                Spacer()
                Button(action: end) {
                    Text("スキップ").font(.label(13)).underline().foregroundStyle(Color.mute)
                        .padding(.vertical, 4).padding(.leading, 12)
                }
                .buttonStyle(.plain)
            }
            Text(title).font(.label(17, black: true))
            Text(message).font(.label(14)).foregroundStyle(Color.ink.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
            if step.advancesByTap {
                Text("タップで次へ ›").font(.label(13, black: true)).foregroundStyle(Color.dopa)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(16)
        .toyCard(radius: 20, shadow: 4)
        .contentShape(.rect)
        .onTapGesture { if step.advancesByTap { advance() } }
        .accessibilityElement(children: .contain)
        .transition(.opacity)
        .id(step)
    }

    /// 進み具合の点。いまの場面だけ長く
    private var dots: some View {
        HStack(spacing: 4) {
            ForEach(TutorialStep.counted, id: \.self) { s in
                Capsule()
                    .fill(s == step ? Color.dopa : s.rawValue < step.rawValue ? Color.ink : Color.rule)
                    .frame(width: s == step ? 20 : 6, height: 6)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("\(step.rawValue + 1) / \(TutorialStep.counted.count)"))
    }

    private var finishCard: some View {
        VStack(spacing: 12) {
            // はじめての幕と同じ3つの言葉。3つ続けて読むと1文になる
            VStack(spacing: 2) {
                Text("食べたら、")
                Text("しゃがんで、")
                Text("叩く。").foregroundStyle(Color.dopa)
            }
            .font(.label(30, black: true))
            .accessibilityElement(children: .combine)
            if firstTime {
                Text("最初の1回で、1日目。").font(.label(15, black: true)).foregroundStyle(Color.mute)
            }
            Button(action: end) {
                Text("はじめる")
                    .font(.label(17, black: true))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.gold, in: .capsule)
                    .overlay(Capsule().strokeBorder(Color.ink, lineWidth: 2))
                    .foregroundStyle(Color.onGold)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .padding(24)
        .toyCard(radius: 24, shadow: 6)
    }

    // MARK: - 文言

    private var title: LocalizedStringResource {
        switch step {
        case .wake: "隊を起こす"
        case .mash: "スクワット1回で、1回叩く"
        case .after: "いまのは練習"
        case .streak: "続けた日"
        case .totals: "ためたドパ"
        case .gear: "回数を変える"
        case .finish: "食べたら、しゃがんで、叩く。"
        }
    }

    private var message: LocalizedStringResource {
        switch step {
        case .wake: "隊は寝ています。ポケットの中で数えないように。画面を長押しして起こしてください。"
        case .mash: "本番は、しゃがんだ回数だけ叩きます。いまは練習。しゃがまずに\(TutorialStep.practiceReps)回どうぞ。"
        case .after: "練習は記録に残りません。本番は、食べてしゃがんだあとに。途中でやめても、叩いた分は残ります。"
        case .streak: "叩いた日は、ここが1日伸びます。休んだ日は、休み券がつなぎます。押すと、今日の記録。"
        case .totals: "スクワット1回が1ドパ。DPW は7日間、DT はこれまでの全部。押すと、履歴。"
        case .gear: "1回に叩く数は、いま\(targetReps)回。ここで\(TargetReps.range.lowerBound)〜\(TargetReps.range.upperBound)回に変えられます。"
        case .finish: firstTime ? "最初の1回で、1日目。" : "食べたら、しゃがんで、叩く。"
        }
    }
}
