import Foundation

/// 記録から計算する数の一式。DT、DPW、連続記録、休み券
///
/// 保存しているのは記録だけなので、起動時と記録を閉じたときに、ここで全部を計算し直す。
nonisolated struct Ledger: Equatable, Sendable {
    /// 1日分の合計。記録日ごとにまとめたドパ（スクワットの回数とフィーバーのドパ）
    ///
    /// 記録は必ずスクワットを1回以上含むので、ドパが0より大きい日は、記録のある日でもある。
    typealias DailyReps = [RecordDay: Int]

    /// 休み券を持てる枚数
    static let maxRestPasses = 2
    /// 連続日数がこの倍数に届くたびに休み券を1枚もらう
    static let restPassInterval = 7
    /// DPW を数える日数（今日を含む）
    static let windowDays = 7

    let today: RecordDay
    /// DT。これまでの全部
    let dopaTotal: Int
    /// DPW。今日と前の6日
    let dopaPerWeek: Int
    /// 前の7日（7日前から13日前）
    let previousWindow: Int
    /// 自己ベスト。昨日までのどこで区切った7日間の合計のうち最大。記録を始めて7日目までは nil
    let bestWindow: Int?
    let streak: Streak

    /// 連続記録と休み券
    struct Streak: Equatable, Sendable {
        /// いまの連続日数。休み券で埋めた日は数えない
        var current = 0
        /// 今日の記録があるか
        var doneToday = false
        /// いま持っている休み券
        var restPasses = 0
        /// 最長記録
        var best = 0
        /// 休み券を使った日（古い順）
        var restPassDays: [RecordDay] = []
        /// いちばん新しい途切れ。途切れた日と、そこまで続いた日数
        var lastBreak: Break?

        struct Break: Equatable, Sendable {
            /// 記録がなく、休み券もなかった日
            let day: RecordDay
            /// 途切れる前の連続日数
            let length: Int
        }

        /// 今日1回叩いたら何日目になるか
        var nextCount: Int { doneToday ? current : current + 1 }
    }

    init(daily: DailyReps, today: RecordDay) {
        self.today = today
        dopaTotal = daily.values.reduce(0, +)
        dopaPerWeek = Self.sum(daily, endingAt: today)
        previousWindow = Self.sum(daily, endingAt: today.adding(days: -Self.windowDays))
        bestWindow = Self.bestWindow(daily, today: today)
        streak = Self.walk(daily, today: today)
    }

    init<S: Sequence>(records: S, today: RecordDay) where S.Element == (day: RecordDay, reps: Int) {
        var daily: DailyReps = [:]
        for r in records { daily[r.day, default: 0] += r.reps }
        self.init(daily: daily, today: today)
    }

    /// end の日で終わる7日間の合計
    private static func sum(_ daily: DailyReps, endingAt end: RecordDay) -> Int {
        (0..<windowDays).reduce(0) { $0 + (daily[end.adding(days: -$1)] ?? 0) }
    }

    /// 昨日までに終わる7日間の合計のうち最大
    ///
    /// 7日まるごとの区間が1つもないうち（記録を始めて7日目まで）は nil。
    /// 区間の途中から始まる短い区間は、同じ日を含む後ろの区間より大きくならないので、
    /// 最初の記録日から昨日までのすべての日を終わりとして調べれば足りる。
    private static func bestWindow(_ daily: DailyReps, today: RecordDay) -> Int? {
        guard let first = daily.keys.min(), today.days(since: first) >= windowDays else { return nil }
        let yesterday = today.adding(days: -1)
        var best = 0
        var end = first
        while end <= yesterday {
            best = max(best, sum(daily, endingAt: end))
            end = end.adding(days: 1)
        }
        return best
    }

    /// 最初の記録日から今日まで1日ずつたどり、連続日数と休み券を決める
    private static func walk(_ daily: DailyReps, today: RecordDay) -> Streak {
        var s = Streak()
        guard var day = daily.keys.min() else { return s }
        while day <= today {
            if (daily[day] ?? 0) > 0 {
                s.current += 1
                s.best = max(s.best, s.current)
                if s.current % restPassInterval == 0 {
                    s.restPasses = min(maxRestPasses, s.restPasses + 1)
                }
                if day == today { s.doneToday = true }
            } else if day < today {
                if s.restPasses > 0 {
                    s.restPasses -= 1
                    s.restPassDays.append(day)
                } else if s.current > 0 {
                    s.lastBreak = .init(day: day, length: s.current)
                    s.current = 0
                }
            }
            // 今日の記録がまだなくても、今日が終わるまでは途切れていない
            day = day.adding(days: 1)
        }
        return s
    }
}
