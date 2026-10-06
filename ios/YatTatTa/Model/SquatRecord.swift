import Foundation
import SwiftData

/// 記録。完了連打1回分
///
/// 端末に保存するのはこれだけ。DT、DPW、連続記録、休み券は、すべて記録から計算する（Ledger）。
@Model final class SquatRecord {
    var id: UUID
    /// 叩き始めた日時
    var startedAt: Date
    /// 記録日（yyyymmdd）。叩き始めた瞬間に決めて書き込む
    var day: Int
    /// ドパに変えたスクワットの回数。1以上
    var reps: Int
    /// フィーバータイムで取ったドパ。スクワットの回数とは別に残す。既定は 0
    var bonusDopa: Int = 0

    init(id: UUID = UUID(), startedAt: Date, day: RecordDay, reps: Int, bonusDopa: Int = 0) {
        self.id = id
        self.startedAt = startedAt
        self.day = day.value
        self.reps = reps
        self.bonusDopa = bonusDopa
    }

    var recordDay: RecordDay { RecordDay(day) }
    /// この記録で入ったドパの全部。DT と DPW に足す
    var dopa: Int { reps + bonusDopa }
}
