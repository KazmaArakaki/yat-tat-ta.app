import SwiftUI
import UIKit

/// フィーバータイム。10秒間、画面のどこを叩いても1打1ドパ。スクワットの残りは減らない
///
/// 画面全体が叩く面になる。ボタンの外を叩いても数えるよう、UIKit の面を一番下に敷く。
struct FeverOverlay: View {
    let model: AppModel
    let state: FeverState
    @State private var landed = false
    @State private var hue = 0.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.black
            RaysView(palette: state.rush ? .gold : .rainbow, period: state.rush ? 0.9 : 1.4)
                // 色を流す。1秒に1周より速くしない
                .hueRotation(.degrees(hue))
            ParticlesView(kind: .coins)
            ParticlesView(kind: .sparks)
            FeverTapSurface(model: model)
            VStack(spacing: 8) {
                MetalText(text: "FEVER!!", size: 92, finish: .dopa)
                    .rotationEffect(.degrees(-6))
                if state.rush {
                    MetalText(text: "RUSH!!", size: 60, finish: .gold)
                } else {
                    MetalText(text: String(localized: "叩き放題"), size: 44, finish: .chrome)
                }
                TimelineView(.periodic(from: .now, by: 0.1)) { context in
                    let left = max(0, state.endsAt.timeIntervalSince(context.date))
                    Text(String(format: "%.1f", left))
                        .font(.number(64))
                        .foregroundStyle(.white)
                        .shadow(color: .black, radius: 0, x: 3, y: 3)
                }
                Text("+\(state.gained) ドパ")
                    .font(.number(46))
                    .foregroundStyle(Color.gold)
                    .shadow(color: .black, radius: 0, x: 3, y: 3)
                    .contentTransition(.numericText(value: Double(state.gained)))
                Text("どこでも叩け！")
                    .font(.label(20, black: true))
                    .foregroundStyle(.white)
            }
            .allowsHitTesting(false)
            .scaleEffect(landed || reduceMotion ? 1 : 3)
            .opacity(landed || reduceMotion ? 1 : 0)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(duration: 0.35, bounce: 0.5)) { landed = true }
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) { hue = 360 }
        }
    }
}

/// フィーバーが終わったときの結果
struct FeverResultOverlay: View {
    let result: FeverResult

    var body: some View {
        VStack(spacing: 0) {
            MetalText(text: "FEVER 終了", size: 44, finish: .chrome, animated: false)
            MetalText(text: "+\(result.gained.formatted())", size: 96, finish: .gold)
            MetalText(text: String(localized: "ドパ"), size: 48, finish: .gold, animated: false)
        }
        .allowsHitTesting(false)
        .transition(.scale(scale: 2.5).combined(with: .opacity))
    }
}

/// フィーバー中の叩く面。指が触れた瞬間に数え、触れた場所から「+10」を飛ばす
private struct FeverTapSurface: UIViewRepresentable {
    let model: AppModel

    func makeUIView(context: Context) -> FeverTapUIView {
        let view = FeverTapUIView()
        view.model = model
        return view
    }

    func updateUIView(_ view: FeverTapUIView, context: Context) {}
}

final class FeverTapUIView: UIView {
    weak var model: AppModel?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError() }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let model else { return }
        for touch in touches {
            guard let tap = model.tap(at: touch.timestamp), tap.isFever else { continue }
            pop("+\(tap.dopa)", at: touch.location(in: self), rush: tap.isRush)
            #if DEBUG
            PerfMonitor.shared?.tapFired(touchedAt: touch.timestamp)
            #endif
        }
    }

    private func pop(_ string: String, at point: CGPoint, rush: Bool) {
        let ring = CAShapeLayer()
        let r: CGFloat = rush ? 120 : 80
        ring.path = UIBezierPath(ovalIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2)).cgPath
        ring.position = point
        ring.fillColor = UIColor.clear.cgColor
        ring.strokeColor = (rush ? Palette.gold : Palette.dopa).cgColor
        ring.lineWidth = 8
        layer.addSublayer(ring)

        let text = CATextLayer()
        text.string = string
        text.font = UIFont.number(10)
        text.fontSize = rush ? 64 : 48
        text.foregroundColor = (rush ? Palette.gold : UIColor.white).cgColor
        text.alignmentMode = .center
        text.contentsScale = window?.screen.scale ?? 3
        text.bounds = CGRect(x: 0, y: 0, width: 240, height: text.fontSize * 1.3)
        text.position = point
        text.shadowColor = Palette.dopa.cgColor
        text.shadowOpacity = 1
        text.shadowRadius = 0
        text.shadowOffset = CGSize(width: 3, height: 3)
        layer.addSublayer(text)

        let reduce = UIAccessibility.isReduceMotionEnabled
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.2
        scale.toValue = 1.4
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        let ringGroup = CAAnimationGroup()
        ringGroup.animations = [scale, fade]
        ringGroup.duration = 0.35

        let rise = CABasicAnimation(keyPath: "position")
        rise.toValue = CGPoint(x: point.x + .random(in: -40...40), y: point.y - (reduce ? 0 : 160))
        rise.timingFunction = CAMediaTimingFunction(name: .easeOut)
        let pop = CAKeyframeAnimation(keyPath: "transform.scale")
        pop.values = [0.3, 1.4, 1]
        pop.keyTimes = [0, 0.2, 1]
        let textFade = CAKeyframeAnimation(keyPath: "opacity")
        textFade.values = [1, 1, 0]
        textFade.keyTimes = [0, 0.65, 1]
        let textGroup = CAAnimationGroup()
        textGroup.animations = [rise, pop, textFade]
        textGroup.duration = 0.6
        textGroup.fillMode = .forwards
        textGroup.isRemovedOnCompletion = false

        CATransaction.begin()
        CATransaction.setCompletionBlock {
            ring.removeFromSuperlayer()
            text.removeFromSuperlayer()
        }
        ring.add(ringGroup, forKey: "pop")
        ring.opacity = 0
        text.add(textGroup, forKey: "pop")
        CATransaction.commit()
    }
}
