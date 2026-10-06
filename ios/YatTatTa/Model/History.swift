import Foundation

/// 履歴のグラフに並べるもの。記録を日の列にまとめる
///
/// 保存はしない。シートを開くたびに、記録を読み直して作る（Ledger と同じ）。
struct History: Equatable {
    /// 少なくともこの日数の列を出す。1画面に見える日数と同じ
    static let minDays = Ledger.windowDays

    /// 人形1つ。記録1件
    struct Entry: Equatable, Identifiable {
        let id: UUID
        let startedAt: Date
        /// 午前4時からの分（0..<1440）。グラフの縦の位置
        let minute: Int
        let reps: Int
        let bonusDopa: Int
        var dopa: Int { reps + bonusDopa }
    }

    /// 日の列
    struct Day: Equatable, Identifiable {
        let day: RecordDay
        /// 叩き始めた順
        let entries: [Entry]
        /// その日のドパ（スクワットの回数とフィーバーのドパ）
        let dopa: Int
        /// 7日移動平均。その日で終わる7日間の合計を7で割る。記録を始める前の日は0ドパ
        let average: Double
        /// 休み券を使った日
        let usedRestPass: Bool
        var id: Int { day.value }
    }

    let today: RecordDay
    /// 古い順。最後が今日
    let days: [Day]
    /// 日ごとのドパの最大。面グラフの目盛りを決める
    let peak: Int

    var isEmpty: Bool { days.allSatisfy(\.entries.isEmpty) }

    /// 最初の列は、最初の記録日と今日の6日前の早いほう。今日より後の記録は並べない
    init(records: [SquatRecord], restPassDays: [RecordDay], today: RecordDay, calendar: Calendar = .current) {
        self.today = today
        var byDay: [RecordDay: [Entry]] = [:]
        for r in records where r.recordDay <= today {
            byDay[r.recordDay, default: []].append(Entry(
                id: r.id, startedAt: r.startedAt, minute: Self.minute(of: r.startedAt, calendar: calendar),
                reps: r.reps, bonusDopa: r.bonusDopa))
        }
        let rest = Set(restPassDays)
        let earliest = today.adding(days: -(Self.minDays - 1))
        var day = min(byDay.keys.min() ?? earliest, earliest)
        var days: [Day] = []
        var window: [Int] = []
        while day <= today {
            let entries = (byDay[day] ?? []).sorted { $0.startedAt < $1.startedAt }
            let dopa = entries.reduce(0) { $0 + $1.dopa }
            window.append(dopa)
            if window.count > Ledger.windowDays { window.removeFirst() }
            days.append(Day(day: day, entries: entries, dopa: dopa,
                            average: Double(window.reduce(0, +)) / Double(Ledger.windowDays),
                            usedRestPass: rest.contains(day)))
            day = day.adding(days: 1)
        }
        self.days = days
        peak = days.map(\.dopa).max() ?? 0
    }

    /// 午前4時からの分。午前1時なら前の日の21時間後
    static func minute(of date: Date, calendar: Calendar = .current) -> Int {
        let shifted = date.addingTimeInterval(-Double(RecordDay.boundaryHour) * 3600)
        let c = calendar.dateComponents([.hour, .minute], from: shifted)
        return min(max((c.hour ?? 0) * 60 + (c.minute ?? 0), 0), 24 * 60 - 1)
    }
}
