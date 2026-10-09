import SwiftUI

/// 今日の記録。連続記録の帯の左側から開く
///
/// 今日（記録日）の記録を新しい順に並べ、左へスワイプして「消す」で1件取り消す。
/// 確かめの問いは挟まない。スワイプと押すことの2手で、うっかりでは起きにくいから。
/// 上に共有のボタンを3つ並べ、今日の記録カードを LINE、X、ほかのアプリへ渡す（docs/features/share-card）。
struct TodayRecordsView: View {
    let model: AppModel
    @Environment(\.dismiss) private var dismiss
    /// 共有している先。LINE と X は、リンクカードを作るのに1、2秒かかる
    @State private var sharing: ShareTarget?

    var body: some View {
        NavigationStack {
            List {
                // 共有のボタン。1度も叩いていない人には、出すものがない
                if model.ledger.dopaTotal > 0 {
                    Section {
                        VStack(spacing: 8) {
                            ForEach(ShareTarget.allCases, id: \.self) { target in
                                ShareTargetButton(target: target, busy: sharing == target) {
                                    sharing = target
                                    Task {
                                        if await ShareService.share(model.shareCard, to: target) { model.markShared() }
                                        sharing = nil
                                    }
                                }
                            }
                        }
                        .disabled(sharing != nil)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    } header: {
                        Text("今日の記録を貼る")
                            .font(.label(13))
                            .foregroundStyle(Color.mute)
                    }
                }
                if model.todayRecords.isEmpty {
                    Section {
                        Text("今日の記録はまだありません。\n叩くと、ここに1件ずつ並びます。")
                            .font(.label(14))
                            .foregroundStyle(Color.mute)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                            .listRowBackground(Color.clear)
                    }
                } else {
                    Section {
                        ForEach(model.todayRecords) { record in
                            RecordRow(record: record)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        withAnimation { model.delete(record) }
                                    } label: {
                                        Text("消す")
                                    }
                                }
                        }
                    } header: {
                        Text("\(model.todayRecords.count)件　\(model.todayRecords.reduce(0) { $0 + $1.dopa })ドパ")
                            .font(.label(13))
                            .foregroundStyle(Color.mute)
                    } footer: {
                        Text("消せるのは今日の分だけ。消すと、連続記録、休み券、DT、DPW を計算し直します。")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.paper)
            .navigationTitle(Text("今日の記録"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Text("閉じる") }
                }
            }
        }
    }
}

/// 1件。叩き始めた時刻、回数、フィーバーのドパ
private struct RecordRow: View {
    let record: SquatRecord

    var body: some View {
        HStack {
            Text(record.startedAt, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
                .font(.number(18))
                .foregroundStyle(Color.ink)
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(verbatim: "\(record.reps)").font(.number(26))
                Text("回").font(.label(13))
            }
            .foregroundStyle(Color.ink)
            if record.bonusDopa > 0 {
                Text("+\(record.bonusDopa) フィーバー")
                    .font(.label(11))
                    .foregroundStyle(Color.dopa)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.dopaSoft, in: .capsule)
                    .padding(.leading, 4)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
