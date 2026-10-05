import SwiftUI
import UIKit

/// 叩く面。SwiftUI のジェスチャーを通さず、UIKit の touchesBegan で指が触れた瞬間に鳴らす
struct FeelPadView: UIViewRepresentable {
    let engine: FeelEngine

    func makeUIView(context: Context) -> FeelPadUIView {
        let view = FeelPadUIView()
        view.engine = engine
        return view
    }

    func updateUIView(_ view: FeelPadUIView, context: Context) {}
}

final class FeelPadUIView: UIView {
    weak var engine: FeelEngine?

    private let glowLayer = CALayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        layer.cornerRadius = 36
        layer.cornerCurve = .continuous
        layer.masksToBounds = true
        backgroundColor = UIColor(red: 0.13, green: 0.10, blue: 0.12, alpha: 1)
        glowLayer.backgroundColor = UIColor(red: 0.90, green: 0.20, blue: 0.48, alpha: 1).cgColor
        glowLayer.opacity = 0
        layer.addSublayer(glowLayer)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        glowLayer.frame = bounds
        CATransaction.commit()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let engine else { return }
        for touch in touches {
            let level = engine.touchDown(at: touch.timestamp)
            if engine.lightOn { flash(at: touch.location(in: self), level: level) }
            engine.recordFired(touchTimestamp: touch.timestamp)
        }
    }

    /// 光。指の位置から輪が広がり、面全体がうっすら光る
    private func flash(at point: CGPoint, level: Int) {
        let t = CGFloat(level) / CGFloat(FeelEngine.levelCount - 1)
        let radius: CGFloat = 70 + 110 * t

        let ring = CAShapeLayer()
        ring.path = UIBezierPath(ovalIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2)).cgPath
        ring.position = point
        ring.fillColor = UIColor(red: 1.0, green: 0.59 + 0.25 * t, blue: 0.75 - 0.55 * t, alpha: 0.9).cgColor
        ring.opacity = 0
        layer.addSublayer(ring)

        let duration = 0.32
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.15
        scale.toValue = 1
        scale.timingFunction = CAMediaTimingFunction(name: .easeOut)
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.timingFunction = CAMediaTimingFunction(name: .easeIn)
        let group = CAAnimationGroup()
        group.animations = [scale, fade]
        group.duration = duration

        CATransaction.begin()
        CATransaction.setCompletionBlock { ring.removeFromSuperlayer() }
        ring.add(group, forKey: "flash")
        CATransaction.commit()

        // 面全体の光は弱めにする。連打しても強い明滅にならないように
        let glow = CABasicAnimation(keyPath: "opacity")
        glow.fromValue = 0.12 + 0.18 * t
        glow.toValue = 0
        glow.duration = 0.2
        glowLayer.add(glow, forKey: "glow")
    }
}
