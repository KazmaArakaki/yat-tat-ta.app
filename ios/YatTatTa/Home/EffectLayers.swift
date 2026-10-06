import SwiftUI
import UIKit

/// 画面全体の演出で使う、Core Animation の部品
///
/// 回り続ける放射線や降り続ける粒は、SwiftUI で毎フレーム描き直すと叩く指への返事を食う。
/// どちらも Core Animation に任せ、メインスレッドの仕事を増やさない。

/// 中心から放射状に伸びる虹色の光。見本2の背景
struct RaysView: UIViewRepresentable {
    enum Palette { case rainbow, gold }

    var palette: Palette = .rainbow
    /// 1周にかかる秒数。小さいほど速い
    var period: Double = 10

    func makeUIView(context: Context) -> RaysUIView { RaysUIView() }

    func updateUIView(_ view: RaysUIView, context: Context) {
        view.configure(palette: palette, period: period)
    }
}

final class RaysUIView: UIView {
    private let gradient = CAGradientLayer()
    private let rays = CAShapeLayer()
    private let glow = CAGradientLayer()
    private var period: Double = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        gradient.type = .conic
        gradient.startPoint = CGPoint(x: 0.5, y: 0.5)
        gradient.endPoint = CGPoint(x: 0.5, y: 0)
        gradient.mask = rays
        layer.addSublayer(gradient)
        glow.type = .radial
        glow.colors = [UIColor.white.withAlphaComponent(0.85).cgColor, UIColor.white.withAlphaComponent(0).cgColor]
        glow.startPoint = CGPoint(x: 0.5, y: 0.5)
        glow.endPoint = CGPoint(x: 1, y: 1)
        layer.addSublayer(glow)
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(palette: RaysView.Palette, period: Double) {
        let hexes: [UInt32] = palette == .rainbow
            ? [0xFF2E63, 0xFF9F1C, 0xFFE14D, 0x3DDC84, 0x22D3EE, 0x2F79F7, 0x8E5CF7, 0xFF2E63]
            : [0xFFF3B0, 0xFFC93C, 0xFF8A00, 0xFFE27A, 0xFFB000, 0xFFF3B0]
        gradient.colors = hexes.map { UIColor(hex: $0).cgColor }
        guard period != self.period else { return }
        self.period = period
        gradient.removeAnimation(forKey: "spin")
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let spin = CABasicAnimation(keyPath: "transform.rotation.z")
        spin.fromValue = 0
        spin.toValue = CGFloat.pi * 2
        spin.duration = period
        spin.repeatCount = .infinity
        gradient.add(spin, forKey: "spin")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // 回しても角が欠けないよう、対角線より大きく取る
        let side = hypot(bounds.width, bounds.height) * 1.1
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradient.bounds = CGRect(x: 0, y: 0, width: side, height: side)
        gradient.position = CGPoint(x: bounds.midX, y: bounds.midY)
        rays.frame = gradient.bounds
        rays.path = Self.rays(in: gradient.bounds, count: 36)
        glow.frame = bounds.insetBy(dx: bounds.width * 0.1, dy: bounds.height * 0.25)
        CATransaction.commit()
    }

    private static func rays(in rect: CGRect, count: Int) -> CGPath {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = rect.width / 2
        let path = UIBezierPath()
        for i in 0..<count {
            let a = CGFloat(i) / CGFloat(count) * .pi * 2
            let w = CGFloat.pi / CGFloat(count) * (i.isMultiple(of: 2) ? 0.75 : 0.35)
            path.move(to: c)
            path.addLine(to: CGPoint(x: c.x + cos(a - w) * r, y: c.y + sin(a - w) * r))
            path.addLine(to: CGPoint(x: c.x + cos(a + w) * r, y: c.y + sin(a + w) * r))
            path.close()
        }
        return path.cgPath
    }
}

/// 降り続ける、または湧き続ける粒
struct ParticlesView: UIViewRepresentable {
    enum Kind {
        /// 画面の下から上がる火の粉
        case embers
        /// 上から降る金の粒（ドパ揃い）
        case coins
        /// 画面じゅうできらめく金（ねぎらい）
        case sparks
    }

    let kind: Kind

    func makeUIView(context: Context) -> ParticlesUIView { ParticlesUIView(kind: kind) }
    func updateUIView(_ view: ParticlesUIView, context: Context) {}
}

final class ParticlesUIView: UIView {
    private let emitter = CAEmitterLayer()
    private let kind: ParticlesView.Kind

    init(kind: ParticlesView.Kind) {
        self.kind = kind
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        emitter.renderMode = .additive
        emitter.emitterCells = cells()
        layer.addSublayer(emitter)
        if UIAccessibility.isReduceMotionEnabled { emitter.birthRate = 0 }
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        emitter.frame = bounds
        switch kind {
        case .embers:
            emitter.emitterShape = .line
            emitter.emitterPosition = CGPoint(x: bounds.midX, y: bounds.maxY + 10)
            emitter.emitterSize = CGSize(width: bounds.width, height: 1)
        case .coins:
            emitter.emitterShape = .line
            emitter.emitterPosition = CGPoint(x: bounds.midX, y: -20)
            emitter.emitterSize = CGSize(width: bounds.width, height: 1)
        case .sparks:
            emitter.emitterShape = .rectangle
            emitter.emitterPosition = CGPoint(x: bounds.midX, y: bounds.midY)
            emitter.emitterSize = bounds.size
        }
    }

    private func cells() -> [CAEmitterCell] {
        func cell(_ color: UInt32, birth: Float, life: Float, velocity: CGFloat, scale: CGFloat) -> CAEmitterCell {
            let c = CAEmitterCell()
            c.contents = Self.dot
            c.color = UIColor(hex: color).cgColor
            c.birthRate = birth
            c.lifetime = life
            c.lifetimeRange = life * 0.4
            c.velocity = velocity
            c.velocityRange = velocity * 0.5
            c.scale = scale
            c.scaleRange = scale * 0.6
            c.alphaSpeed = -1 / life
            return c
        }
        switch kind {
        case .embers:
            return ([0xFF8A00, 0xFFC93C, 0xE5337A] as [UInt32]).map {
                let c = cell($0, birth: 18, life: 2.4, velocity: 220, scale: 0.22)
                c.emissionLongitude = -.pi / 2
                c.emissionRange = .pi / 8
                c.xAcceleration = 10
                return c
            }
        case .coins:
            return ([0xFFD43B, 0xFFB000, 0xFFF3B0] as [UInt32]).map {
                let c = cell($0, birth: 45, life: 2.2, velocity: 380, scale: 0.45)
                c.emissionLongitude = .pi / 2
                c.emissionRange = .pi / 10
                c.yAcceleration = 600
                c.spin = 6
                c.spinRange = 8
                return c
            }
        case .sparks:
            return ([0xFFFFFF, 0xFFE27A] as [UInt32]).map {
                let c = cell($0, birth: 40, life: 0.8, velocity: 20, scale: 0.3)
                c.emissionRange = .pi * 2
                return c
            }
        }
    }

    private static let dot: CGImage? = {
        let size = CGSize(width: 24, height: 24)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.white.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
        }.cgImage
    }()
}

/// 金属の文字。黒い縁取りと奥行き、縦のグラデーションで光らせる（見本2、見本3）
///
/// animated なら、光の筋が文字の上を走り続け、文字が脈打つ。
/// 文字の幅を測り、縁取りと奥行きを含めて maxWidth に収まるまで小さくする。
/// 言語によって文字数が大きく違う（「筋肉」と「MUSCLE」）ので、文字数では決めない。
struct MetalText: View {
    enum Finish { case chrome, gold, dopa }

    let text: String
    /// いちばん大きいときの大きさ
    let size: CGFloat
    var finish: Finish = .chrome
    var animated = true
    /// 縁取りと奥行きを含めた幅の上限。画面の幅から左右の余白を引いた値
    var maxWidth: CGFloat = 340

    @State private var sweep = false
    @State private var beat = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// maxWidth に収まる大きさ。縁取り（左右に 0.075 ずつ）と奥行き（0.06）の分を足して測る
    static func fittedSize(_ text: String, size: CGFloat, maxWidth: CGFloat) -> CGFloat {
        let font = UIFont.systemFont(ofSize: size, weight: .black)
        let perPoint = (text as NSString).size(withAttributes: [.font: font]).width / size
        return min(size, maxWidth / (perPoint + 0.21))
    }

    var body: some View {
        let size = Self.fittedSize(text, size: self.size, maxWidth: maxWidth)
        let font = Font.system(size: size, weight: .black)
        let moving = animated && !reduceMotion
        ZStack {
            // 奥行き。2段重ねて厚みを出す
            Text(text).font(font).foregroundStyle(Color.black.opacity(0.9)).offset(x: size * 0.06, y: size * 0.1)
            Text(text).font(font).foregroundStyle(depth).offset(x: size * 0.03, y: size * 0.05)
            // 縁取り。白の外縁と黒の内縁を、8方向にずらして重ねる
            ForEach(0..<8, id: \.self) { i in
                let a = Double(i) / 8 * .pi * 2
                Text(text).font(font).foregroundStyle(.white)
                    .offset(x: cos(a) * size * 0.075, y: sin(a) * size * 0.075)
            }
            ForEach(0..<8, id: \.self) { i in
                let a = Double(i) / 8 * .pi * 2
                Text(text).font(font).foregroundStyle(Color(red: 0.12, green: 0.06, blue: 0.02))
                    .offset(x: cos(a) * size * 0.045, y: sin(a) * size * 0.045)
            }
            Text(text).font(font).foregroundStyle(fill)
            // 上半分の照り
            Text(text).font(font).foregroundStyle(.white.opacity(0.6))
                .mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .center))
            // 走る光の筋
            if moving {
                Text(text).font(font).foregroundStyle(.white)
                    .mask(
                        GeometryReader { g in
                            LinearGradient(colors: [.clear, .white, .clear], startPoint: .leading, endPoint: .trailing)
                                .frame(width: g.size.width * 0.35)
                                .rotationEffect(.degrees(20))
                                .offset(x: sweep ? g.size.width * 1.2 : -g.size.width * 0.5)
                        }
                    )
            }
        }
        .fixedSize()
        .shadow(color: glow, radius: size * 0.3)
        .shadow(color: glow, radius: size * 0.08)
        .scaleEffect(moving && beat ? 1.06 : 1)
        .onAppear {
            guard moving else { return }
            withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) { sweep = true }
            withAnimation(.easeInOut(duration: 0.28).repeatForever(autoreverses: true)) { beat = true }
        }
    }

    private var fill: LinearGradient {
        let stops: [Color]
        switch finish {
        case .gold:
            stops = [Color(hex: 0xFFFBE0), Color(hex: 0xFFD23F), Color(hex: 0xC97A00), Color(hex: 0xFFE27A), Color(hex: 0x8A4500)]
        case .chrome:
            stops = [Color(hex: 0xF7FFC4), Color(hex: 0xC6F432), Color(hex: 0x4E8000), Color(hex: 0xE8FF8A), Color(hex: 0x2F5A00)]
        case .dopa:
            stops = [Color(hex: 0xFFE0EE), Color(hex: 0xFF5C9D), Color(hex: 0xA3134F), Color(hex: 0xFF9CC4), Color(hex: 0x6B0A33)]
        }
        return LinearGradient(colors: stops, startPoint: .top, endPoint: .bottom)
    }

    private var depth: Color {
        switch finish {
        case .gold: Color(hex: 0x6B3300)
        case .chrome: Color(hex: 0x203D00)
        case .dopa: Color(hex: 0x4A0724)
        }
    }

    private var glow: Color {
        switch finish {
        case .gold: Color(hex: 0xFFB000)
        case .chrome: Color(hex: 0xD9FF5C)
        case .dopa: Color(hex: 0xFF2E7E)
        }
    }
}

/// 中心から画面の外まで広がる衝撃波の輪
struct Shockwave: View {
    var color: Color = .white
    var lineWidth: CGFloat = 14
    @State private var go = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Circle()
            .strokeBorder(color, lineWidth: go ? 1 : lineWidth)
            .frame(width: 80, height: 80)
            .scaleEffect(go ? 14 : 0.5)
            .opacity(go ? 0 : 0.9)
            .allowsHitTesting(false)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeOut(duration: 0.6)) { go = true }
            }
            .opacity(reduceMotion ? 0 : 1)
    }
}

extension Color {
    init(hex: UInt32) { self.init(UIColor(hex: hex)) }
}
