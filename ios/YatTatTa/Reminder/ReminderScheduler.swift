import Foundation
import UserNotifications

/// 今日まだ通知を予約する
///
/// 端末の中だけで出す通知は、届く時刻に「今日もう叩いたか」を確かめられない。
/// そこで先の7日分を予約しておき、開くたび、記録を閉じるたびに予約し直す。
/// 7日目だけは「しばらく止めます」。7日開かれなければ、それきり何も届かない。
final class ReminderScheduler {
    static let count = 7
    private static let idPrefix = "today-reminder-"

    private let center = UNUserNotificationCenter.current()

    /// 通知の許可を求める。許されたら true
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// iPhone の設定で通知が切られているか
    func isDenied() async -> Bool {
        await center.notificationSettings().authorizationStatus == .denied
    }

    func reschedule(enabled: Bool, minutes: Int, ledger: Ledger, target: Int, now: Date = .now,
                    calendar: Calendar = .current) {
        center.removePendingNotificationRequests(withIdentifiers: (0..<Self.count + 1).map { Self.idPrefix + "\($0)" })
        guard enabled else { return }

        var fireDates: [Date] = []
        var day = calendar.startOfDay(for: now)
        while fireDates.count < Self.count {
            let fire = calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: day)!
            let alreadyDone = RecordDay(fire, calendar: calendar) == ledger.today && ledger.streak.doneToday
            if fire > now && !alreadyDone { fireDates.append(fire) }
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }

        for (i, fire) in fireDates.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "Yat Tat Ta"
            content.body = i == Self.count - 1
                ? String(localized: "しばらく通知を止めます。また開いたら再開します。")
                : Self.message(for: RecordDay(fire, calendar: calendar), target: target)
            let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let request = UNNotificationRequest(
                identifier: Self.idPrefix + "\(i)", content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
            center.add(request)
        }
    }

    /// 文面は4つを日ごとに回す。同じ文面が続くと効き目が落ちるため
    static func message(for day: RecordDay, target: Int) -> String {
        let messages = [
            String(localized: "今日はまだです。食べたら、しゃがんで、叩く。"),
            String(localized: "\(target)回で\(target)ドパ。今夜のおやつのあとにでも。"),
            String(localized: "連続記録は、今日の1回でつながります。"),
            String(localized: "1打で1ドパ。今日の分は、まだ0です。"),
        ]
        let index = day.days(since: RecordDay(year: 2026, month: 1, day: 1))
        return messages[(index % messages.count + messages.count) % messages.count]
    }
}
