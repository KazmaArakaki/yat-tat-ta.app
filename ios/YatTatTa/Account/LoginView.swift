import AuthenticationServices
import SwiftUI

/// ログイン画面。まだログインしていない人が、起動して最初に見る
///
/// ボタンは「Appleで続ける」の1つだけ。床で寝ているスクワットマンは、ログインすると起き上がる
/// （docs/ui/pages/login）。
struct LoginView: View {
    let account: Account
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: "Yat Tat ") + Text(verbatim: "Ta").foregroundStyle(Color.dopa)
            Text("機種を変えても、\n記録はそのまま。")
                .font(.label(30, black: true))
                .lineSpacing(4)
                .padding(.top, 28)
            Text("Apple でログインすると、記録がアカウントに残ります。iPhone を替えても、アプリを入れ直しても戻ります。")
                .font(.label(14))
                .foregroundStyle(Color.mute)
                .lineSpacing(3)
                .padding(.top, 14)

            Spacer(minLength: 24)
            sleeper
            Spacer(minLength: 24)

            if account.failure == .signIn {
                Text(Account.Failure.signIn.message)
                    .font(.label(13))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.dopaSoft, in: .rect(cornerRadius: 12))
                    .padding(.bottom, 12)
            }
            SignInWithAppleButton(.continue) { request in
                account.failure = nil
                account.prepare(request)
            } onCompletion: { result in
                Task { await account.complete(result) }
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 50)
            .clipShape(.capsule)
            .disabled(account.busy)
            .overlay {
                if account.busy && !account.welcoming {
                    Capsule().fill(colorScheme == .dark ? Color.white : Color.black)
                    ProgressView().tint(colorScheme == .dark ? .black : .white)
                }
            }
            Text("名前とメールアドレスは受け取りません。")
                .font(.label(11))
                .foregroundStyle(Color.mute)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
        }
        .font(.system(size: 30, weight: .black, design: .rounded))
        .foregroundStyle(Color.ink)
        .padding(.horizontal, 28)
        .padding(.top, 32)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.paper)
    }

    /// 床と、寝ているスクワットマン。ログインできたら起き上がる
    private var sleeper: some View {
        let awake = account.welcoming
        return ZStack(alignment: .bottom) {
            Rectangle().fill(Color.rule).frame(height: 2)
            WakingFigure(awake: awake, animated: !reduceMotion)
                .frame(width: 150, height: 130)
                .padding(.bottom, 1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }
}

/// 寝た姿から立った姿へ。ログインできたときに1度だけ起き上がる
private struct WakingFigure: View {
    let awake: Bool
    let animated: Bool
    @State private var start: Date?

    private static let duration = 0.35

    var body: some View {
        TimelineView(.animation(paused: !animated)) { timeline in
            Canvas { context, size in
                let k = size.height / 110
                SquatFigure.draw(in: context, foot: CGPoint(x: size.width / 2, y: size.height - 4 * k), k: k,
                                 from: SquatterLayer.lie, to: SquatterLayer.stand,
                                 progress: progress(at: timeline.date), color: .gold)
                if !awake { zzz(in: context, size: size, date: timeline.date) }
            }
        }
        .onChange(of: awake) { _, now in start = now ? .now : nil }
    }

    private func progress(at date: Date) -> CGFloat {
        guard awake else { return 0 }
        guard animated, let start else { return 1 }
        let t = min(1, date.timeIntervalSince(start) / Self.duration)
        // 少し行き過ぎてから戻る。長押しで起こすときの跳ね方に似せる
        return CGFloat(1 + 2.2 * pow(t - 1, 3) + 1.2 * pow(t - 1, 2))
    }

    /// 頭の上に浮かぶ Z。動きを減らす設定では止めて出す
    private func zzz(in context: GraphicsContext, size: CGSize, date: Date) {
        let head = CGPoint(x: size.width / 2 - 46 * size.height / 110, y: size.height - 30)
        for i in 0..<3 {
            let t = animated ? (date.timeIntervalSinceReferenceDate / 3.6 + Double(i) / 3).truncatingRemainder(dividingBy: 1) : 0.3 + 0.25 * Double(i)
            let text = Text(verbatim: i == 0 ? "Z" : "z")
                .font(.system(size: 20 - CGFloat(i) * 4, weight: .black, design: .rounded))
                .foregroundStyle(Color.dopa)
            var c = context
            c.opacity = sin(.pi * t)
            c.draw(text, at: CGPoint(x: head.x + 8 + 20 * t, y: head.y - 10 - 50 * t))
        }
    }
}
