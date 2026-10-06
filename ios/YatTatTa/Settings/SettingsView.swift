import SwiftUI

/// 設定シート。目標回数と今日まだ通知だけを置き、一番下に注意書きを添える
struct SettingsView: View {
    let model: AppModel
    @State private var denied = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("目標回数").font(.label(16))
                        Spacer()
                        stepButton("minus", delta: -TargetReps.step)
                        Text(verbatim: "\(model.targetReps)")
                            .font(.number(28))
                            .frame(minWidth: 64)
                            .contentTransition(.numericText(value: Double(model.targetReps)))
                        stepButton("plus", delta: TargetReps.step)
                    }
                } footer: {
                    Text("完了連打で叩く回数。叩き始めたときの回数が、その記録に残ります。")
                }

                Section {
                    Toggle(isOn: Binding(
                        get: { model.reminderEnabled },
                        set: { on in
                            if on { Task { await model.enableReminder(); denied = await model.reminderDenied() } }
                            else { model.reminderEnabled = false }
                        })) {
                        Text("今日まだ通知").font(.label(16))
                    }
                    .tint(Color.dopa)
                    if model.reminderEnabled {
                        DatePicker(selection: Binding(
                            get: { Self.date(minutes: model.reminderMinutes) },
                            set: { model.reminderMinutes = Self.minutes(of: $0) }),
                                   displayedComponents: .hourAndMinute) {
                            Text("時刻").font(.label(16))
                        }
                    }
                    if denied {
                        Button {
                            if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                        } label: {
                            Text("iPhone の設定で通知が切られています。設定を開く")
                                .font(.label(13))
                                .foregroundStyle(Color.dopa)
                        }
                    }
                } footer: {
                    Text("その日まだ叩いていない夜に、1回だけ知らせます。7日開かなければ、自分から止まります。")
                }

                // 注意書き。健康効果は書かず、休んでほしい場面だけを書く（docs/devops/health-wording）
                Section {
                } footer: {
                    Text("膝や腰が痛むとき、医師から運動を止められているときは、休んでください。食べてすぐで気分が悪いときは、少し時間をおいてから。")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.paper)
            .navigationTitle(Text("設定"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Text("閉じる") }
                }
            }
        }
        .task { denied = await model.reminderDenied() }
    }

    private func stepButton(_ symbol: String, delta: Int) -> some View {
        let next = model.targetReps + delta
        return Button {
            withAnimation { model.targetReps = next }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .heavy))
                .frame(width: 40, height: 40)
                .background(Color.gold, in: .circle)
                .overlay(Circle().strokeBorder(Color.ink, lineWidth: 2))
                .foregroundStyle(Color.onGold)
        }
        .buttonStyle(.plain)
        .disabled(!TargetReps.range.contains(next))
        .opacity(TargetReps.range.contains(next) ? 1 : 0.35)
    }

    private static func date(minutes: Int) -> Date {
        Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now
    }

    private static func minutes(of date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
}
