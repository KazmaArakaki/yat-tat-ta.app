import Foundation

/// 共有する今日の記録カードの中身。連続日数、今日のドパ、DPW、7日分のマス目
///
/// いつ出しても同じ形にする。Wordle のマス目のように、見た人が形で覚えられるように（docs/features/share-card）。
/// 体への効果も、パチンコの語も載せない（docs/devops/sns-marketing の決まり1と2）。
nonisolated struct ShareCard: Equatable, Sendable {
    /// 7日分のマス目の1つ
    enum Cell: Equatable, Sendable {
        /// 叩いた日
        case done
        /// 休み券でつないだ日
        case rest
        /// 叩かなかった日。今日まだ叩いていないときの今日も
        case none
    }

    let today: RecordDay
    /// いまの連続日数
    let streak: Int
    let doneToday: Bool
    /// 今日の記録の件数とドパ
    let todaySets: Int
    let todayDopa: Int
    /// DPW
    let dopaPerWeek: Int
    /// 6日前から今日まで、古い順に7つ
    let week: [Cell]

    /// チュートリアルの見本。初めての日に1回叩いたところ
    static func sample(today: RecordDay, reps: Int) -> ShareCard {
        let daily: Ledger.DailyReps = [today: reps]
        return ShareCard(ledger: Ledger(daily: daily, today: today), daily: daily, todaySets: 1)
    }

    init(ledger: Ledger, daily: Ledger.DailyReps, todaySets: Int) {
        today = ledger.today
        streak = ledger.streak.current
        doneToday = ledger.streak.doneToday
        self.todaySets = todaySets
        todayDopa = daily[ledger.today] ?? 0
        dopaPerWeek = ledger.dopaPerWeek
        let rests = Set(ledger.streak.restPassDays)
        week = (0..<Ledger.windowDays).reversed().map { back in
            let day = ledger.today.adding(days: -back)
            if (daily[day] ?? 0) > 0 { return .done }
            return rests.contains(day) ? .rest : .none
        }
    }
}
