import SwiftUI

/// 途切れたときのカード。失ったものより、残っているものを大きく出す
struct StreakBreakCard: View {
    let notice: BreakNotice
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("連続記録は \(notice.length) 日で止まりました")
                .font(.label(17, black: true))
                .multilineTextAlignment(.center)
            HStack(spacing: 12) {
                figure("最長記録", "\(notice.best)", unit: "日")
                figure("DT", "\(notice.dopaTotal)", unit: "ドパ")
            }
            Text("ためた \(notice.dopaTotal) ドパは、そのまま。")
                .font(.label(14))
                .foregroundStyle(Color.mute)
            Button(action: dismiss) {
                Text("今日の1回から")
                    .font(.label(17, black: true))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.gold, in: .capsule)
                    .overlay(Capsule().strokeBorder(Color.ink, lineWidth: 2))
                    .foregroundStyle(Color.onGold)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .toyCard(radius: 24, shadow: 6)
        .padding(16)
    }

    private func figure(_ title: LocalizedStringKey, _ value: String, unit: LocalizedStringKey) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.label(11)).foregroundStyle(Color.mute)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.number(34)).foregroundStyle(Color.dopa)
                Text(unit).font(.label(13, black: true))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.paper, in: .rect(cornerRadius: 14))
    }
}

/// 休み券の帯。つながったという事実だけを伝える
struct RestPassBanner: View {
    let notice: RestPassNotice

    var body: some View {
        Text("休み券を\(notice.used)枚使って、\(notice.streak)日連続をつなぎました")
            .font(.label(14, black: true))
            .foregroundStyle(.white)
            .padding(.horizontal, 16).padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color.signal, in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.ink, lineWidth: 2))
            .padding(.horizontal, 16)
    }
}

/// 今日まだ通知の問いかけ。初めて叩き切ったあとに1度だけ
struct ReminderAskCard: View {
    let minutes: Int
    let answer: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: "🌙").font(.system(size: 28))
            Text("夜、今日まだのときだけ\n知らせますか？")
                .font(.label(20, black: true))
            Text("\(ReminderTimeText(minutes: minutes).text) に1回だけ。叩いた日は鳴りません。設定でいつでも変えられます。")
                .font(.label(13))
                .foregroundStyle(Color.mute)
            HStack(spacing: 12) {
                Button { answer(false) } label: {
                    Text("いらない")
                        .font(.label(16))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .overlay(Capsule().strokeBorder(Color.ink, lineWidth: 2))
                }
                Button { answer(true) } label: {
                    Text("知らせて")
                        .font(.label(16, black: true))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.gold, in: .capsule)
                        .overlay(Capsule().strokeBorder(Color.ink, lineWidth: 2))
                        .foregroundStyle(Color.onGold)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .toyCard(radius: 24, shadow: 6)
        .padding(16)
    }
}

/// 0時からの分を「21:00」の形にする
struct ReminderTimeText {
    let minutes: Int
    var text: String { String(format: "%d:%02d", minutes / 60, minutes % 60) }
}
