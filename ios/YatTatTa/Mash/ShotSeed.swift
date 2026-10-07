#if DEBUG
import Foundation

/// App Store のスクリーンショット用の見本の記録（起動引数 `-seed`）
///
/// 演出の見本（`-demo`）と一緒に使う。昨日まで34日、朝昼晩に目標回数20で叩いた人。
/// 13日前は叩かず、休み券で埋まっている。直近7日は朝昼晩とも叩き、DPW が前の7日より多い。
/// 今日はまだ1件もない（スプラッシュで今日の席が空く）。
/// 乱数の種を決めてあるので、何度撮っても同じ記録になる。撮り直しで数字が変わらない。
///
/// 記録はメモリだけの保存先に入れる。端末に保存された記録には触れない。
/// 撮り方は docs/devops/app-store#screenshots。
enum ShotSeed {
    static let argument = "-seed"
    static var isOn: Bool { ProcessInfo.processInfo.arguments.contains(argument) }

    static let target = 20
    /// 何日前まで記録を作るか
    static let days = 34
    /// 叩かなかった日（何日前か）
    static let skippedDay = 13

    /// 朝、昼、夜の叩き始め。記録日の正午からの時間
    private static let meals: [(hours: Double, spread: Double)] = [(-4.5, 0.6), (0.5, 0.6), (7.5, 1.0)]

    static func records(today: RecordDay, calendar: Calendar = .current) -> [SquatRecord] {
        var random = SplitMix(seed: 20261007)
        var records: [SquatRecord] = []
        for back in stride(from: days, through: 1, by: -1) where back != skippedDay {
            let day = today.adding(days: -back)
            let noon = day.noon(calendar: calendar)
            let recent = back <= 7
            var meals = meals.filter { _ in random.next() > (recent ? 0 : 0.22) }
            // 1日1回は必ず叩いている。連続記録を途切れさせない
            if meals.isEmpty { meals = [Self.meals[2]] }
            for meal in meals {
                let hours = meal.hours + (random.next() * 2 - 1) * meal.spread
                // ときどき多めに叩き、ときどきフィーバーでドパを取る
                let reps = random.next() < (recent ? 0.4 : 0.15) ? 30 : target
                let bonus = random.next() < 0.12 ? 10 + Int(random.next() * 30) : 0
                records.append(SquatRecord(startedAt: noon.addingTimeInterval(hours * 3600), day: day,
                                           reps: reps, bonusDopa: bonus))
            }
        }
        return records
    }

    /// 見本の設定。毎回消してから始める。ふだんの設定には触れない
    static func defaults() -> UserDefaults {
        let name = "com.yat-tat-ta.seed"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        defaults.set(target, forKey: SettingKey.targetReps)
        // 今日まだ通知の問いかけ、チュートリアル、休み券の帯を出さない
        defaults.set(true, forKey: SettingKey.reminderAsked)
        defaults.set(true, forKey: SettingKey.tutorialShown)
        defaults.set(99_991_231, forKey: SettingKey.shownRestPassDay)
        return defaults
    }

    /// 決まった種から 0 以上 1 未満の数を返す
    private struct SplitMix {
        var state: UInt64
        init(seed: UInt64) { state = seed }

        mutating func next() -> Double {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            z ^= z >> 31
            return Double(z >> 11) / Double(1 << 53)
        }
    }
}
#endif
