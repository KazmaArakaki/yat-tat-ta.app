import Foundation

/// スプラッシュの隊列。いまの連続の日を1日1マスで、曜日にそろえて並べる
///
/// 7列で、左上がいちばん古い日、右下が今日。保存しない。Ledger.Streak から毎回作る。
/// 途切れたあとと、まだ1度も叩いていないときは、今日の席だけになる（失ったものを並べない）。
nonisolated struct Lineup: Equatable, Sendable {
    enum Cell: Equatable, Sendable {
        /// 連続が始まる前の、曜日をそろえるための空き
        case blank
        /// 叩いた日。人形が1人立つ
        case past
        /// 休み券を使った日。青い札
        case rest
        /// 今日の席。まだ叩いていない。光の差す床の印
        case seat
        /// 今日の席に、もう人形が立っている
        case today
    }

    /// 並べる週の上限。これより古い週は、数だけ（hidden）にまとめる
    static let maxWeeks = 8
    static let columns = 7

    /// 左上から右へ、行ごとに並べたマス。最後のマスが今日
    let cells: [Cell]
    /// まとめて隠した、叩いた日の数（「＋N日」）
    let hidden: Int

    var rows: Int { (cells.count + Self.columns - 1) / Self.columns }
    /// 人形も札もない。今日の席だけを大きく出す
    var isSeatOnly: Bool { !cells.contains(.past) && !cells.contains(.rest) }

    /// firstWeekday は Calendar.firstWeekday と同じ数え方（1 が日曜）
    init(streak: Ledger.Streak, today: RecordDay, firstWeekday: Int, calendar: Calendar = .current) {
        var list: [Cell] = [streak.doneToday ? .today : .seat]
        // 今日より前に並べる、叩いた日の数。休み券の日は数に入らないので、間に挟む
        var need = streak.doneToday ? streak.current - 1 : streak.current
        let rest = Set(streak.restPassDays)
        var day = today.adding(days: -1)
        while need > 0 {
            if rest.contains(day) {
                list.append(.rest)
            } else {
                list.append(.past)
                need -= 1
            }
            day = day.adding(days: -1)
        }
        list.reverse()

        let weekday = calendar.component(.weekday, from: today.noon(calendar: calendar))
        let todayColumn = (weekday - firstWeekday + 7) % 7
        let lead = ((todayColumn - (list.count - 1)) % 7 + 7) % 7
        var all = Array(repeating: Cell.blank, count: lead) + list

        var hidden = 0
        let rows = (all.count + Self.columns - 1) / Self.columns
        if rows > Self.maxWeeks {
            let drop = (rows - Self.maxWeeks) * Self.columns
            hidden = all.prefix(drop).filter { $0 == .past }.count
            all.removeFirst(drop)
        }
        cells = all
        self.hidden = hidden
    }
}
