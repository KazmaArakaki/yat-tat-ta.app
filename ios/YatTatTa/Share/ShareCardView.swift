import SwiftUI

/// 共有する今日の記録カードの絵。4:5 の縦長で、X にもストーリーにもそのまま貼れる
///
/// 画面の色の設定によらず、いつも明るい色で描く。端末の中で画像にし、サーバーには送らない
/// （docs/features/share-card）。
struct ShareCardView: View {
    let card: ShareCard

    /// 画像にするときの大きさ（ポイント）。3倍で 1080 × 1350 ピクセルになる
    static let size = CGSize(width: 360, height: 450)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                (Text(verbatim: "Yat Tat ") + Text(verbatim: "Ta").foregroundStyle(Color.dopa))
                    .font(.system(size: 24, weight: .black, design: .rounded))
                Spacer()
                Text(card.today.noon(), format: .dateTime.year().month(.twoDigits).day(.twoDigits))
                    .font(.number(14))
                    .foregroundStyle(Color.mute)
            }

            HStack(alignment: .bottom, spacing: 12) {
                Canvas { context, size in
                    let k = size.height / 96
                    SquatFigure.draw(in: context, foot: CGPoint(x: size.width / 2 - 6 * k, y: size.height - 2 * k), k: k,
                                     squat: 1, color: .gold)
                }
                .frame(width: 92, height: 120)
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: "\(card.streak)")
                        .font(.number(112))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text("日連続").font(.label(22, black: true))
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity)
            .toyCard(radius: 24, shadow: 6)
            .padding(.top, 20)

            week.padding(.top, 26)

            HStack(spacing: 10) {
                stat(Text("今日"), value: card.todayDopa, unit: Text("ドパ"))
                stat(Text(verbatim: "DPW"), value: card.dopaPerWeek, unit: Text("ドパ"))
            }
            .padding(.top, 16)

            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline) {
                Text("食べたら、しゃがんで、叩く。").font(.label(13, black: true))
                Spacer()
                Text(verbatim: "yat-tat-ta.web.app").font(.label(11)).foregroundStyle(Color.mute)
            }
        }
        .foregroundStyle(Color.ink)
        .padding(24)
        .frame(width: Self.size.width, height: Self.size.height)
        .background(Color.paper)
        .environment(\.colorScheme, .light)
    }

    /// 6日前から今日までのマス目。叩いた日はピンク、休み券の日は青（アプリの休み券の色）、叩かなかった日は空
    private var week: some View {
        HStack(spacing: 6) {
            ForEach(Array(card.week.enumerated()), id: \.offset) { i, cell in
                let last = i == card.week.count - 1
                VStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color(cell))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.ink, lineWidth: last ? 2.5 : 0))
                        .aspectRatio(1, contentMode: .fit)
                    Text(card.today.adding(days: i - card.week.count + 1).noon(), format: .dateTime.weekday(.narrow))
                        .font(.label(11, black: last))
                        .foregroundStyle(last ? Color.ink : Color.mute)
                }
            }
        }
    }

    private func color(_ cell: ShareCard.Cell) -> Color {
        switch cell {
        case .done: .dopa
        case .rest: .signal
        case .none: .rule
        }
    }

    private func stat(_ label: Text, value: Int, unit: Text) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            label.font(.label(12)).foregroundStyle(Color.mute)
            Spacer(minLength: 0)
            Text(verbatim: "\(value)").font(.number(26))
            unit.font(.label(12))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color.card, in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.rule, lineWidth: 2))
    }
}

extension ShareCardView {
    /// 共有シートに渡す画像
    @MainActor static func render(_ card: ShareCard) -> UIImage? {
        let renderer = ImageRenderer(content: ShareCardView(card: card))
        renderer.scale = 3
        return renderer.uiImage
    }
}

/// iOS の共有シート。送り終えたかを受け取るために、ShareLink ではなく UIActivityViewController を使う
///
/// 送り終えた日は、もう共有を促さない（AppModel.markShared）。閉じただけなら何もしない。
enum ShareSheet {
    @MainActor static func present(_ card: ShareCard, completion: @escaping (Bool) -> Void) {
        guard let image = ShareCardView.render(card), let top = topViewController() else { return }
        let text = String(localized: "Yat Tat Ta で\(card.streak)日連続。食べたら、しゃがんで、叩く。https://yat-tat-ta.web.app")
        let controller = UIActivityViewController(activityItems: [image, text], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in completion(completed) }
        top.present(controller, animated: true)
    }

    /// いちばん上に出ている画面。今日の記録のシートの上からも出せるように
    @MainActor private static func topViewController() -> UIViewController? {
        let window = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows).first { $0.isKeyWindow }
        var top = window?.rootViewController
        while let next = top?.presentedViewController { top = next }
        return top
    }
}

/// 共有を促すカード。今日の記録があって、今日まだ共有していないとき、ホームの下から出す
///
/// アプリを開いたときと、叩き切ったあとの演出が終わったときに出る。「今日はしない」でその日は出さない。
struct SharePromptCard: View {
    let card: ShareCard
    let share: () -> Void
    let decline: () -> Void
    @State private var image: UIImage?

    var body: some View {
        VStack(spacing: 14) {
            Text("今日の記録を貼りませんか")
                .font(.label(17, black: true))
                .multilineTextAlignment(.center)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(4 / 5, contentMode: .fit)
                    .frame(height: 220)
                    .clipShape(.rect(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.ink, lineWidth: 2))
                    .accessibilityLabel(Text("今日の記録カード。\(card.streak)日連続"))
            }
            Text("X や LINE に、今日の記録カードを貼れます。")
                .font(.label(13))
                .foregroundStyle(Color.mute)
                .multilineTextAlignment(.center)
            HStack(spacing: 10) {
                Button(action: decline) {
                    Text("今日はしない")
                        .font(.label(15, black: true))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .overlay(Capsule().strokeBorder(Color.ink, lineWidth: 2))
                        .foregroundStyle(Color.ink)
                }
                .buttonStyle(.plain)
                Button(action: share) {
                    Text("共有する")
                        .font(.label(15, black: true))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.gold, in: .capsule)
                        .overlay(Capsule().strokeBorder(Color.ink, lineWidth: 2))
                        .foregroundStyle(Color.onGold)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .toyCard(radius: 24, shadow: 6)
        .padding(16)
        .task(id: card) { image = ShareCardView.render(card) }
    }
}
