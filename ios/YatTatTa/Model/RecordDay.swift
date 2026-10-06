import Foundation

/// 記録日。午前4時で区切った日付を yyyymmdd の整数で持つ
///
/// 記録を作った瞬間の端末の時刻で決めて、記録に書き込む。
/// あとから計算し直さないので、時差のある場所で開いても日は動かない。
nonisolated struct RecordDay: Hashable, Comparable, Sendable, CustomStringConvertible {
    /// 午前4時より前は前の日
    static let boundaryHour = 4

    let value: Int

    init(_ value: Int) {
        self.value = value
    }

    init(year: Int, month: Int, day: Int) {
        value = year * 10000 + month * 100 + day
    }

    /// date が属する記録日。calendar のタイムゾーン（既定は端末）で決める
    init(_ date: Date, calendar: Calendar = .current) {
        let shifted = date.addingTimeInterval(-Double(Self.boundaryHour) * 3600)
        let c = calendar.dateComponents([.year, .month, .day], from: shifted)
        self.init(year: c.year!, month: c.month!, day: c.day!)
    }

    var description: String { String(value) }

    static func < (lhs: RecordDay, rhs: RecordDay) -> Bool { lhs.value < rhs.value }

    /// n 日後（負なら前）の記録日
    func adding(days n: Int) -> RecordDay {
        // 正午から4時間戻しても同じ日なので、そのまま記録日に戻せる
        RecordDay(Self.utc.date(byAdding: .day, value: n, to: noonUTC)!, calendar: Self.utc)
    }

    /// other から self まで何日あるか
    func days(since other: RecordDay) -> Int {
        Self.utc.dateComponents([.day], from: other.noonUTC, to: noonUTC).day!
    }

    /// 記録日の正午。日付を画面に出すために使う
    func noon(calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: value / 10000, month: value / 100 % 100, day: value % 100, hour: 12))!
    }

    // 日の足し引きは、夏時間のない UTC の暦で行う
    private static let utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private var noonUTC: Date {
        Self.utc.date(from: DateComponents(year: value / 10000, month: value / 100 % 100, day: value % 100, hour: 12))!
    }
}
