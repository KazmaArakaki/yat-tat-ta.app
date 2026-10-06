import SwiftUI

/// 連続記録の帯。左に日数、右に休み券
///
/// 今日まだなら「1回で何日目か」を出す。途切れたあとも「0日」とは出さない。
/// 左側（日数と一言）は、今日の記録を開くボタン。叩いている最中は押せない。
struct StreakBar: View {
    let streak: Ledger.Streak
    /// 今日の記録の件数
    let todayCount: Int
    var openToday: () -> Void = {}
    var canOpenToday = true

    var body: some View {
        HStack(alignment: .top) {
            Button(action: openToday) {
                VStack(alignment: .leading, spacing: 4) {
                    headline
                    HStack(spacing: 4) {
                        Text(subline)
                        if todayCount > 0 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundStyle(Color.mute)
                        }
                    }
                    .font(.label(13))
                    .foregroundStyle(streak.doneToday ? Color.dopa : Color.mute)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .disabled(!canOpenToday)
            .accessibilityElement(children: .combine)
            .accessibilityHint(Text("今日の記録を開きます"))
            Spacer()
            restPasses
        }
    }

    @ViewBuilder private var headline: some View {
        if streak.current > 0 {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(verbatim: "\(streak.current)")
                    .font(.number(44))
                    .foregroundStyle(Color.dopa)
                    .contentTransition(.numericText(value: Double(streak.current)))
                Text("日連続").font(.label(15, black: true))
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(streak.best > 0 ? "今日の1回で" : "最初の1回で").font(.label(15, black: true))
                Text(verbatim: "1").font(.number(44)).foregroundStyle(Color.dopa)
                Text("日目").font(.label(15, black: true))
            }
        }
    }

    private var subline: LocalizedStringKey {
        if streak.doneToday { return todayCount > 0 ? "✓ 今日のぶんは済み（\(todayCount)回）" : "✓ 今日のぶんは済み" }
        if streak.current > 0 { return "今日はまだ。1回で\(streak.nextCount)日目" }
        if streak.best > 0 { return "最長記録 \(streak.best)日" }
        return "食べたら、しゃがんで、叩く"
    }

    /// 2枚分の枠を常に出し、持っていない枠は点線にする
    private var restPasses: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("休み券").font(.label(11)).foregroundStyle(Color.mute)
            HStack(spacing: 4) {
                ForEach(0..<Ledger.maxRestPasses, id: \.self) { i in
                    if i < streak.restPasses {
                        RoundedRectangle(cornerRadius: 4).fill(Color.signal)
                            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.ink, lineWidth: 2))
                    } else {
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Color.mute, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                    }
                }
                .frame(width: 22, height: 16)
            }
        }
        .accessibilityLabel(Text("休み券 \(streak.restPasses)枚"))
    }
}
