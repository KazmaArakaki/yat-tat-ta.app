#if DEBUG
import Foundation

/// 計測モード（起動引数 `-perf`）の仮の記録
///
/// 目標回数100を叩き切った最後の1打で、連続30日、DT 1,000、DPW の自己ベスト更新が重なり、
/// 同じ1打でフィーバーが当たる。フィーバーのドパは最後の1打より後に入るので、
/// 叩く速さが変わっても、節目が重なる1打は動かない。
///
/// 記録はメモリだけの保存先に入れる。端末に保存された記録には触れない。
enum PerfSeed {
    static let argument = "-perf"
    static var isOn: Bool { ProcessInfo.processInfo.arguments.contains(argument) }

    static let target = 100

    /// 昨日までの29日分。古い順。合計 900、直近6日の合計 141、自己ベスト 240（13日前から7日前）
    ///
    /// 最後の1打の前で DPW は 141 + 99 = 240 になり、自己ベストに並ぶ。最後の1打で超える。
    static let dailyReps: [Int] = [24] + Array(repeating: 33, count: 21) + [42] + [24, 24, 24, 23, 23, 23]

    static func records(today: RecordDay, now: Date) -> [SquatRecord] {
        dailyReps.enumerated().map { i, reps in
            SquatRecord(startedAt: now, day: today.adding(days: i - dailyReps.count), reps: reps)
        }
    }

    /// 計測モードの設定。毎回消してから始める。ふだんの設定には触れない
    static func defaults() -> UserDefaults {
        let name = "com.yat-tat-ta.perf"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        defaults.set(target, forKey: SettingKey.targetReps)
        // 今日まだ通知の問いかけを出さない
        defaults.set(true, forKey: SettingKey.reminderAsked)
        return defaults
    }

    /// フィーバーのくじ。スクワットの100打目だけ当たる
    final class FeverDraw {
        private var count = 0

        func next() -> Double {
            count += 1
            return count % PerfSeed.target == 0 ? 0 : 1
        }

        func reset() { count = 0 }
    }
}
#endif
