import Foundation

/// 節目。届いた1打で、フィナーレの下に札を1枚積む
nonisolated enum Milestone: Equatable, Hashable, Sendable {
    /// DT が value ドパに届いた
    case dopaTotal(Int)
    /// 連続記録が value 日に届いた
    case streak(Int)
    /// DPW が自己ベスト value を超えた
    case bestWindow(Int)

    static let dopaTotalSteps = [100, 1_000, 10_000, 100_000]
    static let streakSteps = [7, 30, 100, 365]

    /// DT が before から after に増えたときにまたいだ節目
    static func dopaTotal(from before: Int, to after: Int) -> [Milestone] {
        dopaTotalSteps.filter { before < $0 && $0 <= after }.map { .dopaTotal($0) }
    }

    /// 連続日数が days になったときの節目。365日を超えたら365日ごと
    static func streak(reaching days: Int) -> Milestone? {
        if streakSteps.contains(days) || (days > 365 && days % 365 == 0) { return .streak(days) }
        return nil
    }

    /// DPW が before から after に増えたときに、自己ベスト best を超えたか
    ///
    /// 超えたあとは1打ごとに更新になるので、超えた1打だけを節目にする。
    /// その日のうちに DPW は減らないので、1日に1回までになる。
    static func bestWindow(best: Int?, from before: Int, to after: Int) -> Milestone? {
        guard let best, before <= best, after > best else { return nil }
        return .bestWindow(best)
    }
}
