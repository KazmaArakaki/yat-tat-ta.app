import SwiftUI
import UIKit

/// 完了連打の叩く場所。画面中央の広い範囲で、スクワット隊がしゃがむ
///
/// SwiftUI のジェスチャーは指を離したときに反応するので、UIKit の touchesBegan で指が触れた瞬間に受ける。
/// 叩いた瞬間の数字と動きは UIKit の中で直接変え、SwiftUI の描き直しを待たない。
struct SquatStageView: UIViewRepresentable {
    let model: AppModel

    func makeUIView(context: Context) -> SquatStageUIView {
        let view = SquatStageUIView()
        view.model = model
        view.sync()
        return view
    }

    func updateUIView(_ view: SquatStageUIView, context: Context) {
        view.sync()
    }
}

final class SquatStageUIView: UIView {
    weak var model: AppModel?

    /// スクワットこの回数ごとに1人増える
    static let recruitEvery = 2
    /// 上限30人。51人では実機で音が乱れ、叩いた返事が遅れた（2026-10-06）
    static let maxMembers = 30

    private let caption = UILabel()
    /// 残りの数。パーティーパロット風に、色が虹を巡り、小さく円を描いて揺れる
    ///
    /// number は色を塗る面（parrotFill）の型抜きとして使い、影は numberShadow で別に描く。
    private let number = UILabel()
    private let numberShadow = UILabel()
    private let numberBox = UIView()
    private let parrotFill = UIView()
    private var parrotStage: HypeStage?
    /// 残りの数の文字の大きさ。叩くたびに少しずつ大きくなる
    private var numberSize: CGFloat = SquatStageUIView.numberBaseSize
    static let numberBaseSize: CGFloat = 84
    /// 最後の1打で、ここまで大きくなる
    static let numberMaxSize: CGFloat = 170
    private let gained = UILabel()
    private let comboLabel = UILabel()
    private let stamp = UILabel()
    private let crowd = CALayer()
    private let halo = CAGradientLayer()
    private var members: [SquatterLayer] = []
    private var squatting = false
    private var stage = HypeStage.normal
    private var comboHide: DispatchWorkItem?
    private var reduceMotion: Bool { UIAccessibility.isReduceMotionEnabled }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        clipsToBounds = false

        // 虹の先バレ。隊の後ろで回る輪
        halo.type = .conic
        halo.colors = ([0xFF3B5C, 0xFF9F1C, 0xFFE14D, 0x3DDC84, 0x2F79F7, 0x8E5CF7, 0xFF3B5C] as [UInt32])
            .map { UIColor(hex: $0).cgColor }
        halo.startPoint = CGPoint(x: 0.5, y: 0.5)
        halo.endPoint = CGPoint(x: 0.5, y: 0)
        halo.mask = CAShapeLayer()
        halo.isHidden = true
        layer.addSublayer(halo)
        layer.addSublayer(crowd)

        caption.font = .systemFont(ofSize: 15, weight: .black)
        caption.textColor = Palette.mute
        number.textColor = .black
        number.textAlignment = .center
        numberShadow.textColor = UIColor.black.withAlphaComponent(0.85)
        numberShadow.textAlignment = .center
        setNumberFont(Self.numberBaseSize)
        parrotFill.backgroundColor = Palette.ink
        parrotFill.mask = number
        numberBox.addSubview(numberShadow)
        numberBox.addSubview(parrotFill)
        numberBox.layer.zPosition = 60
        numberBox.isUserInteractionEnabled = false
        addSubview(numberBox)
        gained.font = .number(30)
        gained.textColor = Palette.dopa
        comboLabel.font = .number(24)
        comboLabel.textColor = Palette.dopa
        comboLabel.alpha = 0
        for label in [caption, gained, comboLabel] {
            label.textAlignment = .center
            // 隊より手前に出し、暗転した地や放射線の上でも読めるよう黒い影を付ける
            label.layer.zPosition = 60
            label.layer.shadowColor = UIColor.black.cgColor
            label.layer.shadowOpacity = 0.85
            label.layer.shadowRadius = 0
            label.layer.shadowOffset = CGSize(width: 2, height: 3)
            addSubview(label)
        }

        stamp.text = String(localized: "激熱")
        stamp.font = .systemFont(ofSize: 30, weight: .black)
        stamp.textColor = .white
        stamp.textAlignment = .center
        stamp.backgroundColor = Palette.dopa
        stamp.layer.borderColor = Palette.onGold.cgColor
        stamp.layer.borderWidth = 3
        stamp.layer.cornerRadius = 10
        stamp.clipsToBounds = true
        stamp.isHidden = true
        addSubview(stamp)

        isAccessibilityElement = true
        accessibilityTraits = [.button, .allowsDirectInteraction]
        setMembers(1, animated: false)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - 置き方

    /// 隊の足元が並ぶ場所
    private var crowdFrame: CGRect {
        CGRect(x: 0, y: 112, width: bounds.width, height: max(0, bounds.height - 112 - 48))
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        caption.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 20)
        // 揺れのアニメーションは transform にかけているので、frame ではなく bounds と center で置く
        let boxHeight = numberSize * 1.25
        numberBox.bounds = CGRect(x: 0, y: 0, width: bounds.width, height: boxHeight)
        numberBox.center = CGPoint(x: bounds.midX, y: 16 + boxHeight / 2)
        parrotFill.frame = numberBox.bounds
        number.frame = parrotFill.bounds
        numberShadow.frame = numberBox.bounds.offsetBy(dx: 3, dy: 4)
        comboLabel.frame = CGRect(x: 0, y: 104, width: bounds.width, height: 28)
        gained.frame = CGRect(x: 0, y: bounds.height - 40, width: bounds.width, height: 36)
        stamp.frame = CGRect(x: bounds.width - 104, y: 20, width: 84, height: 46)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        crowd.frame = crowdFrame
        for (i, member) in members.enumerated() { place(member, slot: i) }
        let side = min(crowdFrame.width, crowdFrame.height) * 0.95
        halo.frame = CGRect(x: crowdFrame.midX - side / 2, y: crowdFrame.midY - side / 2, width: side, height: side)
        (halo.mask as? CAShapeLayer).map {
            $0.path = UIBezierPath(ovalIn: CGRect(origin: .zero, size: halo.bounds.size).insetBy(dx: 8, dy: 8)).cgPath
            $0.fillColor = UIColor.clear.cgColor
            $0.strokeColor = UIColor.black.cgColor
            $0.lineWidth = 14
        }
        CATransaction.commit()
    }

    /// 席の位置。手前の列の真ん中から埋め、左右、奥の列へ。奥ほど小さい
    private static let slots: [(row: Int, column: Int)] = {
        var result: [(Int, Int)] = []
        for row in 0..<7 {
            let half = 1 + row
            result.append((row, 0))
            for c in 1...half {
                result.append((row, -c))
                result.append((row, c))
            }
        }
        return result
    }()

    private func place(_ member: SquatterLayer, slot: Int) {
        let (row, column) = Self.slots[min(slot, Self.slots.count - 1)]
        let area = crowdFrame
        let scales: [CGFloat] = [1, 0.76, 0.6, 0.49, 0.41, 0.35, 0.3]
        let baselines: [CGFloat] = [0.9, 0.69, 0.53, 0.41, 0.31, 0.23, 0.16]
        let frontHeight = min(area.height * 0.62, 200)
        let height = frontHeight * scales[row]
        let spacing = area.width / CGFloat(3 + 2 * row) * 0.98
        member.height = height
        member.position = CGPoint(x: area.width / 2 + CGFloat(column) * spacing - height * 0.05,
                                  y: area.height * baselines[row])
        member.zPosition = CGFloat(10 - row)
    }

    // MARK: - 状態を写す

    func sync() {
        guard let model else { return }
        // 叩き切ったあとは、フィナーレの間だけ 0 と変えた数を残す
        if let finale = model.finale, finale.completed {
            setNumber("0")
            caption.text = String(localized: "やったった")
            gained.text = String(localized: "+\(finale.reps) ドパ")
            return
        }
        // 段階は AppModel に合わせる。入った瞬間の演出は touchesBegan の enter で出す
        let modelStage = model.session.isOpen ? model.hypeStage : .normal
        if stage != modelStage { applyStage(modelStage) }
        // 人数はスクワットの回数で決まる。閉じたら1人に戻る
        let desired = model.session.isOpen ? 1 + model.session.converted / Self.recruitEvery : 1
        if desired != members.count { setMembers(desired, animated: desired > members.count) }
        setRainbow(model.rainbow)
        setNumber("\(model.remaining)")
        // 叩くたびに少しずつ大きくする。進み具合に比べて、最後の1打で numberMaxSize
        let progress = model.session.isOpen
            ? CGFloat(model.session.converted) / CGFloat(max(model.session.target, 1)) : 0
        setNumberFont(Self.numberBaseSize + (Self.numberMaxSize - Self.numberBaseSize) * min(progress, 1))
        setParrot(model.session.isOpen ? stage : nil)
        if stage < .push {
            caption.text = model.session.isOpen ? String(localized: "スクワット 残り") : String(localized: "スクワット")
        }
        gained.text = model.converted > 0 ? String(localized: "+\(model.converted) ドパ") : String(localized: "叩いてしゃがむ")
        accessibilityLabel = String(localized: "完了連打。スクワット 残り \(model.remaining)")
    }

    /// 隊の人数をそろえる。増えた人は跳ねて現れる
    private func setMembers(_ count: Int, animated: Bool) {
        let count = min(max(count, 1), Self.maxMembers)
        while members.count > count { members.removeLast().removeFromSuperlayer() }
        while members.count < count {
            let member = SquatterLayer(contentsScale: window?.screen.scale ?? 3)
            members.append(member)
            crowd.addSublayer(member)
            place(member, slot: members.count - 1)
            member.setPose(squat: squatting, duration: 0)
            if animated {
                if !reduceMotion {
                    let pop = CASpringAnimation(keyPath: "transform.scale")
                    pop.fromValue = 0.1
                    pop.toValue = 1
                    pop.damping = 9
                    pop.initialVelocity = 12
                    pop.duration = pop.settlingDuration
                    member.add(pop, forKey: "pop")
                }
                popText(String(localized: "+1人"), at: crowd.convert(member.position, to: layer))
            }
        }
        recolor()
    }

    private func recolor() {
        let palette: [UIColor] = [Palette.gold, Palette.dopa, Palette.signal]
        for (i, member) in members.enumerated() {
            let color: UIColor = switch stage {
            case .hot: Palette.dopa
            case .push: Palette.gold
            default: palette[i % palette.count]
            }
            member.color = color
        }
    }

    // MARK: - 叩く

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let model else { return }
        for touch in touches {
            let point = touch.location(in: self)
            guard let tap = model.tap(at: touch.timestamp) else { continue }
            squat(true)
            ring(at: point, tap: tap)
            if tap.enteredStage { enter(tap.stage) }
            if !reduceMotion {
                grain(from: point)
                // 激熱からは1打で3つ飛ばし、画面を小さく揺らす
                for _ in 0..<(tap.stage >= .hot ? 3 : 1) { shout(at: point, tap: tap) }
                if tap.stage >= .hot && !tap.isFinal { nudgeScreen() }
            }
            showCombo(tap.combo)
            if tap.isFinal {
                setNumber("0")
                if !reduceMotion { burst() }
            } else {
                sync()
            }
            #if DEBUG
            PerfMonitor.shared?.tapFired(touchedAt: touch.timestamp)
            #endif
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        standIfReleased(event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        standIfReleased(event)
    }

    /// 指が全部離れたら立つ
    private func standIfReleased(_ event: UIEvent?) {
        let stillDown = event?.touches(for: self)?.contains { $0.phase != .ended && $0.phase != .cancelled } ?? false
        if !stillDown { squat(false) }
    }

    override func accessibilityActivate() -> Bool {
        _ = model?.tap(at: ProcessInfo.processInfo.systemUptime)
        squat(true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { self.squat(false) }
        sync()
        return true
    }

    /// 隊の全員が揃ってしゃがむ。しゃがむのは速く、立ち上がりは少し遅く
    private func squat(_ down: Bool) {
        guard down != squatting else { return }
        squatting = down
        for member in members { member.setPose(squat: down, duration: down ? 0.08 : 0.12) }
    }

    // MARK: - ドパドパ

    private func applyStage(_ new: HypeStage) {
        stage = new
        stamp.isHidden = new < .hot
        if new == .push { caption.text = "PUSH!" }
        recolor()
    }

    private func enter(_ new: HypeStage) {
        applyStage(new)
        switch new {
        case .hot:
            slamStamp()
            if !reduceMotion { shakeScreen() }
        case .push:
            let bump = CABasicAnimation(keyPath: "transform.scale")
            bump.fromValue = 1.5
            bump.toValue = 1
            bump.duration = 0.2
            parrotFill.layer.add(bump, forKey: "push")
            numberShadow.layer.add(bump, forKey: "push")
        case .normal, .chance:
            break
        }
    }

    // MARK: - パーティーパロット

    private func setNumber(_ text: String) {
        number.text = text
        numberShadow.text = text
    }

    private func setNumberFont(_ size: CGFloat) {
        guard size != numberSize || number.font.pointSize != size else { return }
        let grew = size > numberSize
        numberSize = size
        number.font = .number(size)
        numberShadow.font = .number(size)
        setNeedsLayout()
        // 大きくなった1打は、少し跳ねて見せる
        if grew && !reduceMotion {
            let bump = CABasicAnimation(keyPath: "transform.scale")
            bump.fromValue = 1.15
            bump.toValue = 1
            bump.duration = 0.12
            parrotFill.layer.add(bump, forKey: "grow")
            numberShadow.layer.add(bump, forKey: "grow")
        }
    }

    /// 叩いている間だけ、残りの数をパーティーパロット風にする。nil なら止めて ink 色に戻す
    ///
    /// 色は虹の12色を1秒で1周させる。光に敏感な人のため、1秒に1周より速くしない（UI の基本方針）。
    /// 揺れは段階が上がるほど速くなる。視差効果を減らす設定では揺らさない。
    private func setParrot(_ stage: HypeStage?) {
        guard stage != parrotStage else { return }
        parrotStage = stage
        guard let stage else {
            parrotFill.layer.removeAnimation(forKey: "parrot")
            numberBox.layer.removeAnimation(forKey: "wobble")
            parrotFill.backgroundColor = Palette.ink
            return
        }
        if parrotFill.layer.animation(forKey: "parrot") == nil {
            let colors = (0..<12).map { UIColor(hue: CGFloat($0) / 12, saturation: 0.85, brightness: 1, alpha: 1).cgColor }
            let cycle = CAKeyframeAnimation(keyPath: "backgroundColor")
            cycle.values = colors + [colors[0]]
            cycle.calculationMode = .discrete
            cycle.duration = 1
            cycle.repeatCount = .infinity
            parrotFill.layer.add(cycle, forKey: "parrot")
        }
        numberBox.layer.removeAnimation(forKey: "wobble")
        guard !reduceMotion else { return }
        // 小さく円を描きながら、左右に首をかしげる
        let period: CFTimeInterval = [0.6, 0.45, 0.35, 0.25][stage.rawValue]
        let radius: CGFloat = 5 + 2 * CGFloat(stage.rawValue)
        let steps = 10
        let move = CAKeyframeAnimation(keyPath: "transform")
        move.values = (0...steps).map { i -> NSValue in
            let a = CGFloat(i) / CGFloat(steps) * .pi * 2
            var t = CATransform3DMakeTranslation(cos(a) * radius, sin(a) * radius * 0.6, 0)
            t = CATransform3DRotate(t, sin(a) * 0.14, 0, 0, 1)
            return NSValue(caTransform3D: t)
        }
        move.duration = period
        move.repeatCount = .infinity
        numberBox.layer.add(move, forKey: "wobble")
    }

    private func slamStamp() {
        stamp.transform = reduceMotion ? CGAffineTransform(rotationAngle: -0.2)
            : CGAffineTransform(scaleX: 2.4, y: 2.4).rotated(by: -0.5)
        stamp.alpha = reduceMotion ? 1 : 0
        UIView.animate(withDuration: 0.22, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0,
                       options: [.allowUserInteraction]) {
            self.stamp.transform = CGAffineTransform(rotationAngle: -0.2)
            self.stamp.alpha = 1
        }
    }

    private func shakeScreen() {
        let target = window?.rootViewController?.view.layer ?? layer
        let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
        shake.values = [0, -12, 12, -8, 8, -3, 0]
        shake.duration = 0.32
        target.add(shake, forKey: "shake")
    }

    /// 1打ごとの小さな揺れ。激熱から
    private func nudgeScreen() {
        let target = window?.rootViewController?.view.layer ?? layer
        let shake = CAKeyframeAnimation(keyPath: "transform.translation")
        shake.values = [CGSize.zero, CGSize(width: .random(in: -5...5), height: .random(in: -5...5)), CGSize.zero]
            .map { NSValue(cgSize: $0) }
        shake.duration = 0.09
        target.add(shake, forKey: "nudge")
    }

    private func setRainbow(_ on: Bool) {
        guard halo.isHidden == on else { return }
        halo.isHidden = !on
        if on {
            let spin = CABasicAnimation(keyPath: "transform.rotation.z")
            spin.fromValue = 0
            spin.toValue = CGFloat.pi * 2
            spin.duration = reduceMotion ? 6 : 1.2
            spin.repeatCount = .infinity
            halo.add(spin, forKey: "spin")
        } else {
            halo.removeAllAnimations()
        }
    }

    // MARK: - 1打の返し

    /// 指の位置から広がる輪
    private func ring(at point: CGPoint, tap: MashSession.Tap) {
        let t = CGFloat(tap.level) / CGFloat(MashSession.levelCount - 1)
        let radius: CGFloat = 70 + 110 * t
        let ring = CAShapeLayer()
        ring.path = UIBezierPath(ovalIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2)).cgPath
        ring.position = point
        ring.fillColor = UIColor.clear.cgColor
        ring.strokeColor = (tap.stage >= .hot ? Palette.gold : Palette.dopa).cgColor
        ring.lineWidth = 4 + 6 * t
        ring.opacity = 0
        layer.addSublayer(ring)

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.2
        scale.toValue = 1
        scale.timingFunction = CAMediaTimingFunction(name: .easeOut)
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0.9
        fade.toValue = 0
        let group = CAAnimationGroup()
        group.animations = [scale, fade]
        group.duration = 0.34
        CATransaction.begin()
        CATransaction.setCompletionBlock { ring.removeFromSuperlayer() }
        ring.add(group, forKey: "ring")
        CATransaction.commit()
    }

    /// 1打で1粒。指の位置から「+N ドパ」へ飛ぶ
    private func grain(from point: CGPoint) {
        let dot = CALayer()
        dot.bounds = CGRect(x: 0, y: 0, width: 14, height: 14)
        dot.cornerRadius = 7
        dot.backgroundColor = Palette.dopa.cgColor
        dot.position = point
        layer.addSublayer(dot)

        let end = CGPoint(x: gained.center.x + .random(in: -30...30), y: gained.center.y)
        let path = UIBezierPath()
        path.move(to: point)
        path.addQuadCurve(to: end, controlPoint: CGPoint(x: (point.x + end.x) / 2 + .random(in: -90...90),
                                                          y: min(point.y, end.y) - 40))
        let move = CAKeyframeAnimation(keyPath: "position")
        move.path = path.cgPath
        move.timingFunction = CAMediaTimingFunction(name: .easeIn)
        let shrink = CABasicAnimation(keyPath: "transform.scale")
        shrink.fromValue = 1.2
        shrink.toValue = 0.5
        let group = CAAnimationGroup()
        group.animations = [move, shrink]
        group.duration = 0.36
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            dot.removeFromSuperlayer()
            let bump = CABasicAnimation(keyPath: "transform.scale")
            bump.fromValue = 1.25
            bump.toValue = 1
            bump.duration = 0.14
            self?.gained.layer.add(bump, forKey: "bump")
        }
        dot.add(group, forKey: "grain")
        CATransaction.commit()
    }

    /// 指の位置から「ドパ」の文字が飛ぶ。段階と勢いで大きくなり、速く叩き続けると「ドパドパ」になる
    private func shout(at point: CGPoint, tap: MashSession.Tap) {
        let text = tap.isFever ? "+\(tap.dopa)" : (tap.combo >= 4 ? "ドパドパ" : "ドパ")
        let size = 44 + 16 * CGFloat(tap.stage.rawValue) + min(CGFloat(tap.combo), 20) * 1.2
        popText(text, at: point, size: size, rise: 160 + 60 * CGFloat(tap.stage.rawValue), spread: 140,
                color: tap.stage >= .hot ? Palette.gold : Palette.dopa,
                shadow: tap.stage >= .hot ? Palette.dopa : Palette.onGold)
    }

    private func popText(_ string: String, at point: CGPoint, size: CGFloat = 30, rise: CGFloat = 70,
                         spread: CGFloat = 10, color: UIColor = Palette.dopa, shadow: UIColor = Palette.onGold) {
        let text = CATextLayer()
        text.string = string
        text.font = UIFont.systemFont(ofSize: 10, weight: .black)
        text.fontSize = size
        text.foregroundColor = color.cgColor
        text.alignmentMode = .center
        text.contentsScale = window?.screen.scale ?? 3
        text.bounds = CGRect(x: 0, y: 0, width: max(240, size * 6), height: size * 1.3)
        text.position = point
        text.shadowColor = shadow.cgColor
        text.shadowOpacity = 1
        text.shadowRadius = 0
        text.shadowOffset = CGSize(width: 4, height: 4)
        text.zPosition = 50
        layer.addSublayer(text)

        let up = CABasicAnimation(keyPath: "position")
        up.toValue = CGPoint(x: point.x + .random(in: -spread...spread), y: point.y - (reduceMotion ? 0 : rise))
        up.timingFunction = CAMediaTimingFunction(name: .easeOut)
        let pop = CAKeyframeAnimation(keyPath: "transform.scale")
        pop.values = [0.4, 1.2, 1]
        pop.keyTimes = [0, 0.25, 1]
        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = [1, 1, 0]
        fade.keyTimes = [0, 0.6, 1]
        let group = CAAnimationGroup()
        group.animations = [up, pop, fade]
        group.duration = 0.6
        group.fillMode = .forwards
        group.isRemovedOnCompletion = false
        CATransaction.begin()
        CATransaction.setCompletionBlock { text.removeFromSuperlayer() }
        text.add(group, forKey: "pop")
        CATransaction.commit()
    }

    /// 「ドパドパ ×N」。3打続いたら出し、止まって0.6秒で消す
    private func showCombo(_ combo: Int) {
        comboHide?.cancel()
        guard combo >= 3 else {
            comboLabel.alpha = 0
            return
        }
        comboLabel.text = String(localized: "ドパドパ ×\(combo)")
        comboLabel.alpha = 1
        let bump = CABasicAnimation(keyPath: "transform.scale")
        bump.fromValue = 1.3
        bump.toValue = 1
        bump.duration = 0.12
        comboLabel.layer.add(bump, forKey: "bump")
        let hide = DispatchWorkItem { [weak self] in
            UIView.animate(withDuration: 0.2) { self?.comboLabel.alpha = 0 }
        }
        comboHide = hide
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: hide)
    }

    /// 叩き切ったときの粒。CAEmitterLayer は粒の動きを GPU 側で計算するので、1打ごとの仕事を増やさない
    private func burst() {
        let emitter = CAEmitterLayer()
        emitter.emitterPosition = CGPoint(x: crowdFrame.midX, y: crowdFrame.midY)
        emitter.emitterShape = .circle
        emitter.emitterSize = CGSize(width: 200, height: 200)
        emitter.renderMode = .additive
        emitter.zPosition = 40
        emitter.emitterCells = [Palette.dopa, Palette.gold, Palette.signal].map { color in
            let cell = CAEmitterCell()
            cell.contents = Self.dotImage
            cell.color = color.cgColor
            cell.birthRate = 220
            cell.lifetime = 1.2
            cell.velocity = 420
            cell.velocityRange = 200
            cell.emissionRange = .pi * 2
            cell.yAcceleration = 420
            cell.scale = 0.55
            cell.scaleRange = 0.3
            cell.alphaSpeed = -0.8
            return cell
        }
        layer.addSublayer(emitter)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { emitter.birthRate = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { emitter.removeFromSuperlayer() }
    }

    private static let dotImage: CGImage? = {
        let size = CGSize(width: 24, height: 24)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.white.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
        }.cgImage
    }()
}

/// スクワットをする人1人。横向きの棒人間を、太い ink の線の上に色の線を重ねて描く
///
/// 立つ姿としゃがむ姿は、同じ数の点でできた線なので、線の形ごと動かせる。
/// 位置（position）は足首の場所。
final class SquatterLayer: CALayer {
    /// 足首から頭のてっぺんまでの高さ
    var height: CGFloat = 160 { didSet { redraw() } }
    var color: UIColor = Palette.gold { didSet { applyColor() } }

    private let outline = CAShapeLayer()
    private let body = CAShapeLayer()
    private let headOutline = CAShapeLayer()
    private let head = CAShapeLayer()
    private var squatting = false

    init(contentsScale: CGFloat) {
        super.init()
        self.contentsScale = contentsScale
        for shape in [outline, body] {
            shape.fillColor = UIColor.clear.cgColor
            shape.lineCap = .round
            shape.lineJoin = .round
            addSublayer(shape)
        }
        addSublayer(headOutline)
        addSublayer(head)
        applyColor()
        redraw()
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) { fatalError() }

    /// 高さ100のときの関節の位置。足首が原点、上がマイナス
    private struct Pose {
        let legs: [CGPoint]   // つま先、足首、膝、腰、肩
        let arm: [CGPoint]    // 肩、肘、手
        let head: CGPoint
    }

    private static let stand = Pose(
        legs: [.init(x: 12, y: 0), .init(x: 0, y: 0), .init(x: 0, y: -21), .init(x: 0, y: -42), .init(x: 0, y: -72)],
        arm: [.init(x: 0, y: -72), .init(x: 4, y: -58), .init(x: 6, y: -46)],
        head: .init(x: 2, y: -86))

    private static let squat = Pose(
        legs: [.init(x: 12, y: 0), .init(x: 0, y: 0), .init(x: 15, y: -15), .init(x: -7, y: -25), .init(x: 3, y: -55)],
        arm: [.init(x: 3, y: -55), .init(x: 17, y: -55), .init(x: 31, y: -56)],
        head: .init(x: 7, y: -69))

    private var k: CGFloat { height / 100 }

    private func path(_ pose: Pose) -> CGPath {
        let p = UIBezierPath()
        for points in [pose.legs, pose.arm] {
            p.move(to: scaled(points[0]))
            for point in points.dropFirst() { p.addLine(to: scaled(point)) }
        }
        return p.cgPath
    }

    private func scaled(_ point: CGPoint) -> CGPoint { CGPoint(x: point.x * k, y: point.y * k) }

    private func headPath(radius: CGFloat) -> CGPath {
        UIBezierPath(ovalIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2)).cgPath
    }

    private func redraw() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let pose = squatting ? Self.squat : Self.stand
        outline.lineWidth = 15 * k
        body.lineWidth = 9 * k
        outline.path = path(pose)
        body.path = path(pose)
        headOutline.path = headPath(radius: 12 * k)
        head.path = headPath(radius: 8.5 * k)
        headOutline.position = scaled(pose.head)
        head.position = scaled(pose.head)
        CATransaction.commit()
    }

    private func applyColor() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        outline.strokeColor = Palette.onGold.cgColor
        headOutline.fillColor = Palette.onGold.cgColor
        body.strokeColor = color.cgColor
        head.fillColor = color.cgColor
        CATransaction.commit()
    }

    func setPose(squat down: Bool, duration: CFTimeInterval) {
        squatting = down
        let pose = down ? Self.squat : Self.stand
        let newPath = path(pose)
        let newHead = scaled(pose.head)
        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: down ? .easeIn : .easeOut))
        if duration == 0 { CATransaction.setDisableActions(true) }
        for shape in [outline, body] {
            let animation = CABasicAnimation(keyPath: "path")
            animation.fromValue = shape.presentation()?.path ?? shape.path
            animation.toValue = newPath
            animation.duration = duration
            shape.path = newPath
            if duration > 0 { shape.add(animation, forKey: "pose") }
        }
        for shape in [headOutline, head] {
            let animation = CABasicAnimation(keyPath: "position")
            animation.fromValue = shape.presentation()?.position ?? shape.position
            animation.toValue = newHead
            animation.duration = duration
            shape.position = newHead
            if duration > 0 { shape.add(animation, forKey: "pose") }
        }
        CATransaction.commit()
    }
}
