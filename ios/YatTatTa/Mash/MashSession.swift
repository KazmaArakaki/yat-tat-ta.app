import Foundation

/// 完了連打1回分の、叩いている途中の状態
///
/// 叩いている間は端末に書き込まない。閉じたときに AppModel が記録を1件保存する。
nonisolated struct MashSession: Sendable {
    /// 最後の1打から、この秒数叩かなければ閉じる
    static let idleTimeout: TimeInterval = 60
    /// 叩き切ったあと、この秒数は叩いても数えない。勢い余った指で次の記録が始まらないように
    static let lockAfterFinale: TimeInterval = 1.2
    /// この秒数以内に次を叩くと、光が強まる
    static let comboWindow: TimeInterval = 0.45
    static let levelCount = 8

    /// フィーバータイムが当たる確率。スクワットの1打ごとに独立に引く
    static let feverChance = 0.0051
    static let feverDuration: TimeInterval = 10
    /// 最後のこの秒数はラッシュ。演出だけが強まり、1打のドパは変わらない
    static let feverRush: TimeInterval = 3

    /// 叩き始めたときの目標回数。途中で設定を変えても、この連打の間は変わらない
    private(set) var target: Int
    /// ドパに変えたスクワットの回数
    private(set) var converted = 0
    /// この連打のフィーバーで取ったドパ
    private(set) var feverDopa = 0
    private(set) var startedAt: Date?
    /// 連打の勢い（0〜7）。光の強さに使う
    private(set) var momentum = 0
    /// 0.45秒以内に続けて叩いた打数。「ドパドパ ×N」に出す
    private(set) var combo = 0
    /// フィーバーが終わる時刻（touch.timestamp と同じ時計）。フィーバー中でなければ nil
    private(set) var feverEndsAt: TimeInterval?
    /// この連打で届いた節目
    var milestones: [Milestone] = []

    private var lastTap: TimeInterval = -.infinity
    private var lockedUntil: TimeInterval = -.infinity

    init(target: Int) {
        self.target = target
    }

    var remaining: Int { target - converted }
    var isOpen: Bool { startedAt != nil }
    /// この連打で入ったドパの全部
    var dopa: Int { converted + feverDopa }

    struct Tap: Equatable, Sendable {
        /// 何打目のスクワットか（1から）。フィーバーの1打では増えない
        let index: Int
        /// 進み具合の段階（0〜7）。音の高さと振動の強さ
        let level: Int
        /// 連打の勢い（0〜7）。光の強さ
        let momentum: Int
        /// 続けて叩いた打数
        let combo: Int
        /// この1打のあとのドパドパの段階
        let stage: HypeStage
        /// この1打で段階が上がったか
        let enteredStage: Bool
        /// スクワットの最後の1打か
        let isFinal: Bool
        /// この1打で入ったドパ。スクワットでもフィーバーでも1（倍率は付けない）
        let dopa: Int
        /// フィーバーの1打か
        let isFever: Bool
        /// フィーバーの最後の3秒（ラッシュ）の1打か
        let isRush: Bool
        /// この1打でフィーバーが当たったか
        let startedFever: Bool
    }

    /// 1打。叩いても数えない間は nil。新しく始めるときは、そのときの目標回数を使う
    ///
    /// draw はフィーバーのくじ。0以上1未満の数を返す。テストでは決まった数を渡す。
    mutating func tap(at time: TimeInterval, date: Date, target newTarget: Int,
                      draw: () -> Double = { Double.random(in: 0..<1) }) -> Tap? {
        guard time >= lockedUntil else { return nil }
        if !isOpen {
            target = newTarget
            converted = 0
            feverDopa = 0
            feverEndsAt = nil
            startedAt = date
            milestones = []
            momentum = 0
            combo = 1
        } else if time - lastTap <= Self.comboWindow {
            momentum = min(momentum + 1, Self.levelCount - 1)
            combo += 1
        } else {
            momentum = 0
            combo = 1
        }
        lastTap = time

        // フィーバーの1打。スクワットの残りは止めたまま、ドパだけを1足す。中ではくじを引かない
        if let end = feverEndsAt, time < end {
            feverDopa += 1
            return Tap(index: converted, level: Self.levelCount - 1, momentum: momentum, combo: combo,
                       stage: Self.stage(index: max(converted, 1), target: target), enteredStage: false,
                       isFinal: false, dopa: 1, isFever: true, isRush: end - time <= Self.feverRush,
                       startedFever: false)
        }
        feverEndsAt = nil

        converted += 1
        let isFinal = converted >= target
        let startedFever = draw() < Self.feverChance
        if startedFever { feverEndsAt = time + Self.feverDuration }
        // 最後の1打でフィーバーが当たったら、数えない間はフィーバーが終わってから
        if isFinal && !startedFever { lockedUntil = time + Self.lockAfterFinale }
        let stage = Self.stage(index: converted, target: target)
        let previous = converted > 1 ? Self.stage(index: converted - 1, target: target) : .normal
        return Tap(index: converted, level: Self.level(index: converted, target: target),
                   momentum: momentum, combo: combo, stage: stage, enteredStage: stage != previous,
                   isFinal: isFinal, dopa: 1, isFever: false, isRush: false, startedFever: startedFever)
    }

    /// フィーバーを終える。叩き切ったあとに当たっていたら、ここから数えない間に入る
    mutating func endFever(at time: TimeInterval) {
        feverEndsAt = nil
        if remaining <= 0 { lockedUntil = time + Self.lockAfterFinale }
    }

    /// 閉じる。叩いた分があれば、叩き始めた日時、スクワットの回数、フィーバーのドパを返す
    mutating func close() -> (startedAt: Date, reps: Int, bonusDopa: Int)? {
        defer {
            startedAt = nil
            converted = 0
            feverDopa = 0
            feverEndsAt = nil
            momentum = 0
            combo = 0
        }
        guard let startedAt, converted > 0 else { return nil }
        return (startedAt, converted, feverDopa)
    }

    /// ドパドパの段階。くじにせず、何打目まで来たかで決める。同じ目標回数なら毎回同じ1打で上がる
    ///
    /// PUSH は残りが3になった1打から（目標回数が10より少なければ残り1から）。
    /// 入り口が同じ1打に重なったら、強いほうだけになる。
    static func stage(index: Int, target: Int) -> HypeStage {
        let remaining = target - index
        if remaining <= (target >= 10 ? 3 : 1) { return .push }
        if Double(index) >= (Double(target) * 0.6).rounded(.up) { return .hot }
        if Double(index) >= (Double(target) * 0.3).rounded(.up) { return .chance }
        return .normal
    }

    /// 目標回数を8つに割り、何打目かで段階を決める。最後の1打はいつも最上段
    static func level(index: Int, target: Int) -> Int {
        let raw = Int((Double(index) / Double(max(target, 1)) * Double(levelCount)).rounded(.up)) - 1
        return min(max(raw, 0), levelCount - 1)
    }
}

/// ドパドパの段階。パチンコの煽り演出の文法を借りる
nonisolated enum HypeStage: Int, Comparable, Sendable {
    case normal, chance, hot, push

    static func < (lhs: HypeStage, rhs: HypeStage) -> Bool { lhs.rawValue < rhs.rawValue }
}
