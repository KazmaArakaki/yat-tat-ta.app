import SwiftUI

/// 画面全体の地。ドパドパの段階で変わる
///
/// 叩き始めたら NORMAL でも薄い放射線が回り出し、叩くたびに衝撃波が画面の外まで走る。
/// CHANCE で四辺が dopa 色に光り、激熱で暗転して虹の放射線と火の粉、PUSH で放射線が全速になる。
struct StageBackdrop: View {
    let stage: HypeStage
    /// 叩いている途中か
    let active: Bool
    /// 叩くたびに変わる。衝撃波と四辺の光を1打ごとに出す
    let tick: Int

    var body: some View {
        ZStack {
            Color.paper
            if active && stage < .hot {
                RaysView(palette: .rainbow, period: stage == .chance ? 5 : 9)
                    .opacity(stage == .chance ? 0.35 : 0.18)
            }
            if stage >= .hot {
                Color.black
                RaysView(palette: .rainbow, period: stage == .push ? 1.6 : 4)
                    .opacity(stage == .push ? 1 : 0.8)
                ParticlesView(kind: .embers)
                ParticlesView(kind: .sparks).opacity(0.6)
            }
            if active {
                Shockwave(color: stage >= .hot ? .gold : .dopa, lineWidth: stage >= .hot ? 22 : 12)
                    .offset(y: 70)
                    .id(tick)
            }
            if stage >= .chance {
                EdgeGlow(color: stage >= .hot ? .gold : .dopa, strength: 1)
                    .id(tick)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .animation(.easeOut(duration: 0.25), value: stage)
    }
}

/// 画面の四辺の光。叩いた瞬間に強く、0.4秒で落ちる。白く光らせないので、明滅の回数には数えない
private struct EdgeGlow: View {
    let color: Color
    let strength: Double
    @State private var lit = true

    var body: some View {
        RoundedRectangle(cornerRadius: 48)
            .strokeBorder(color, lineWidth: 40)
            .blur(radius: 26)
            .opacity(lit ? strength : strength * 0.5)
            .onAppear {
                withAnimation(.easeOut(duration: 0.4)) { lit = false }
            }
    }
}

/// 段階に入った1打。画面いっぱいに「CHANCE!!」「激熱!!」「PUSH!!」を叩きつける
struct StageBannerOverlay: View {
    let banner: StageBanner
    @State private var landed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            RaysView(palette: banner.stage == .chance ? .rainbow : .gold, period: 1.5)
                .opacity(0.55)
                .mask(RadialGradient(colors: [.white, .clear], center: .center, startRadius: 40, endRadius: 360))
            Shockwave(color: .white, lineWidth: 26)
            MetalText(text: title, size: banner.stage == .hot ? 120 : 84, finish: finish)
                .rotationEffect(.degrees(-8))
                .scaleEffect(landed || reduceMotion ? 1 : 3.5)
                .opacity(landed || reduceMotion ? 1 : 0)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.spring(duration: 0.3, bounce: 0.55)) { landed = true }
        }
    }

    private var title: String {
        switch banner.stage {
        case .chance: "CHANCE!!"
        case .hot: String(localized: "激熱!!")
        case .push: "PUSH!!"
        case .normal: ""
        }
    }

    private var finish: MetalText.Finish {
        switch banner.stage {
        case .chance: .dopa
        case .hot: .gold
        default: .chrome
        }
    }
}

/// ドパ突破。DT が100の倍数をまたいだ1打で、画面いっぱいに「300／ドパ突破」
struct ToppaOverlay: View {
    let event: ToppaEvent
    @State private var landed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
            RaysView(palette: event.gold ? .gold : .rainbow, period: 1.8)
                .opacity(0.9)
            ParticlesView(kind: .coins)
            Shockwave(color: event.gold ? .gold : .white, lineWidth: 30)
            VStack(spacing: -6) {
                MetalText(text: event.value.formatted(), size: event.value >= 10_000 ? 96 : 130,
                          finish: event.gold ? .gold : .chrome)
                MetalText(text: String(localized: "ドパ突破"), size: 72, finish: event.gold ? .gold : .dopa)
            }
            .rotationEffect(.degrees(-5))
            .scaleEffect(landed || reduceMotion ? 1 : 4)
            .opacity(landed || reduceMotion ? 1 : 0)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.spring(duration: 0.35, bounce: 0.5)) { landed = true }
        }
    }
}
