import Foundation

/// 端末の設定（UserDefaults）に置く小さな値。消えても既定値に戻るだけ
enum SettingKey {
    /// 目標回数
    static let targetReps = "targetReps"
    /// 今日まだ通知を出すか
    static let reminderEnabled = "reminderEnabled"
    /// 今日まだ通知の時刻（0時からの分）
    static let reminderMinutes = "reminderMinutes"
    /// 今日まだ通知を1度聞いたか
    static let reminderAsked = "reminderAsked"
    /// どの途切れまでカードを見せたか（記録日）
    static let shownBreakDay = "shownBreakDay"
    /// どの日に使った休み券まで帯を見せたか（記録日）
    static let shownRestPassDay = "shownRestPassDay"
    /// 確定の言葉を何回出したか。5つを順に回す
    static let kakuteiCount = "kakuteiCount"
    /// ねぎらいの言葉を何回回したか
    static let negiraiCount = "negiraiCount"
    /// はじめての幕を出したか。1度きり
    static let introShown = "introShown"
}

enum TargetReps {
    static let `default` = 20
    static let range = 5...100
    static let step = 5
}

enum ReminderTime {
    /// 既定は 21:00
    static let defaultMinutes = 21 * 60
}
