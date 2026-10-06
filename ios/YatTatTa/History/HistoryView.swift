import SwiftUI

/// 履歴。DPW と DT のカードから開く
///
/// これまでの記録を、日付と時刻の上に人形で並べる。人形を押すと、下にその記録が出る。
/// 見るだけで、消せない。今日の1件を消すのは今日の記録から。
struct HistoryView: View {
    let history: History
    @Environment(\.dismiss) private var dismiss
    @State private var selected: HistorySelection?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 10) {
                legend
                HistoryChart(history: history, selected: $selected)
                    .frame(maxHeight: .infinity)
                detail
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
            .background(Color.paper)
            .navigationTitle(Text("履歴"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Text("閉じる") }
                }
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 14) {
            swatch(Color.dopa, opacity: 0.2, Text("日ごとのドパ"))
            swatch(Color.signal, opacity: 0.15, Text("7日移動平均"))
        }
        .font(.label(11))
        .foregroundStyle(Color.mute)
        .padding(.leading, 4)
        .accessibilityHidden(true)
    }

    private func swatch(_ color: Color, opacity: Double, _ label: Text) -> some View {
        HStack(spacing: 4) {
            Rectangle().fill(color.opacity(opacity))
                .overlay(alignment: .top) { Rectangle().fill(color).frame(height: 2) }
                .frame(width: 14, height: 10)
            label
        }
    }

    /// 押した記録。押す前は今日の合計
    private var detail: some View {
        let day = selected?.day ?? history.days.last!
        return VStack(alignment: .leading, spacing: 4) {
            if history.isEmpty {
                Text("叩くと、ここに人形が並びます。")
                    .font(.label(13))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            } else {
                HStack(spacing: 6) {
                    Text(day.day.noon(), format: .dateTime.month(.defaultDigits).day().weekday(.abbreviated))
                    if day.day == history.today { Text("今日") }
                    Text("\(day.entries.count)件　\(day.dopa)ドパ　7日平均 \(Int(day.average.rounded()))")
                }
                .font(.label(11))
                .foregroundStyle(Color.mute)
                if let entry = selected?.entry {
                    HStack(alignment: .firstTextBaseline) {
                        Text(entry.startedAt, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
                            .font(.number(22))
                        Spacer()
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(verbatim: "\(entry.reps)").font(.number(26))
                            Text("回").font(.label(13))
                        }
                        if entry.bonusDopa > 0 {
                            Text("+\(entry.bonusDopa) フィーバー")
                                .font(.label(11))
                                .foregroundStyle(Color.dopa)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.dopaSoft, in: .capsule)
                                .padding(.leading, 4)
                        }
                    }
                    .foregroundStyle(Color.ink)
                } else {
                    Text("人形を押すと、その記録が出ます。")
                        .font(.label(13))
                        .foregroundStyle(Color.ink)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .toyCard(radius: 16, shadow: 3)
        .accessibilityElement(children: .combine)
    }
}
