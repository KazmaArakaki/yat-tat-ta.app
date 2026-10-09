import SwiftUI

/// はじめての幕。インストールして最初の起動で1度だけ（14.0秒）
///
/// 場面ごとに一呼吸おく。言葉は1つずつ出して、読み終わる間を置いてから次へ。
/// 1人の人形が、食べて、しゃがんで、連続タップ、をゆっくりやって見せ、
/// その人形が今週の隊列の左端（今日の席）に入って消える。明日からの6人を1人ずつ立たせて見せてから、
/// 今日の席と「1人目は、今日のあなたです。」だけを残す。
struct IntroSplash: View {
    let target: CGRect?
    var calendar: Calendar = .current
    var beats: ([FeelEngine.Beat]) -> Void = { _ in }
    var finish: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var clock = SplashClock()

    /// 時刻（秒）。見本の INTRO と同じ
    enum T {
        /// Yat / Tat / Ta。最初の0.6秒は地の色だけ
        static let beats = [0.6, 1.0, 1.4]
        /// 「食べて、」人形が静かに立つ
        static let eat = 2.6
        /// 「しゃがんで、」1.4秒かけて1回
        static let squat = 3.8
        /// 「連続タップ。」0.3秒おいて、足元から輪とドパの粒
        static let tap = 5.4
        static let tapHit = tap + 0.3
        /// 一呼吸のあと、人形が今日の席へ縮んで入り、今週の席が並ぶ
        static let row = 7.0
        /// 明日からの6人が、1人ずつ立つ
        static let glimpse = 8.8
        /// ほかの席が引き、今日の席と「1人目」の一言だけになる
        static let seat = 11.0
        static let seatHit = seat + 1.0
        static let handoff = 13.6
        static let end = 14.0
        /// 叩くと、次の場面の頭へ進む（一度に最後まで飛ばない）
        static let chapters = [eat, squat, tap, row, glimpse, seat, handoff]
        static let allBeats: [FeelEngine.Beat] =
            beats.map { .init(at: $0, strong: false) } + [.init(at: tapHit, strong: true), .init(at: seatHit, strong: true)]
    }

    var body: some View {
        TimelineView(.animation(paused: clock.origin == nil)) { context in
            let t = clock.time(at: context.date)
            let hu = SplashMath.at(t, T.handoff, T.end - T.handoff)
            let fade = 1 - SplashMath.clamp(hu * 2)
            ZStack(alignment: .topLeading) {
                Color.paper.opacity(1 - SplashMath.clamp(hu * 2.5)).ignoresSafeArea()
                GeometryReader { geo in
                    let layout = Layout(size: geo.size)
                    ZStack(alignment: .topLeading) {
                        Canvas { ctx, _ in draw(in: ctx, layout: layout, t: t) }
                            .opacity(fade)
                        wordmark(t: t)
                            .opacity(fade)
                        words(t: t, layout: layout)
                        SplashNumber(prefix: "最初の1回で", number: 1, suffix: "日目", t: t, handoff: T.handoff, end: T.end,
                                     target: target, still: reduceMotion,
                                     opacity: SplashMath.easeSine(SplashMath.at(t, T.seat + 1.0, 0.5)))
                            .offset(x: SplashOverlay.Layout.margin, y: layout.infoTop)
                        Text("1人目は、今日のあなたです。")
                            .font(.label(15, black: true))
                            .opacity(SplashMath.easeSine(SplashMath.at(t, T.seat + 1.6, 0.5)) * fade)
                            .offset(x: SplashOverlay.Layout.margin, y: layout.infoTop + 102)
                    }
                }
            }
        }
        .foregroundStyle(Color.ink)
        .contentShape(.rect)
        .onTapGesture { next() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "Yat Tat Ta. ") + Text("食べて、しゃがんで、連続タップ。") + Text(verbatim: " ")
                            + Text("1日1回で、1人ずつ。") + Text(verbatim: " ") + Text("1人目は、今日のあなたです。"))
        .onAppear {
            clock.start()
            beats(T.allBeats)
        }
        .task(id: clock.origin) {
            guard clock.origin != nil else { return }
            #if DEBUG
            // 止めて見ているあいだは消さない
            if SplashClock.frozen != nil { return }
            #endif
            try? await Task.sleep(for: .seconds(max(0, T.end - clock.time(at: .now))))
            guard !Task.isCancelled else { return }
            finish()
        }
    }

    /// 次の場面の頭へ。飛ばした場面の振動は鳴らさない
    private func next() {
        let now = clock.time(at: .now)
        guard let to = T.chapters.first(where: { $0 > now + 0.05 }) else { return }
        clock.jump(to: to)
        beats(T.allBeats.filter { $0.at >= to }.map { .init(at: $0.at - to, strong: $0.strong) })
    }

    // MARK: 置き方

    struct Layout {
        let size: CGSize
        let infoTop: CGFloat
        /// やって見せる人形の足元
        let stage: CGPoint
        /// 今週の席の床の高さ
        let rowBase: CGFloat
        let cellWidth: CGFloat
        static let bigK: CGFloat = 2.1
        static let rowK: CGFloat = 0.46
        static let seatK: CGFloat = 1.3

        init(size: CGSize) {
            self.size = size
            infoTop = size.height * 0.66
            stage = CGPoint(x: size.width / 2, y: infoTop - 74)
            rowBase = infoTop - 102
            cellWidth = (size.width - SplashOverlay.Layout.margin * 2) / 7
        }

        func seat(_ i: Int) -> CGPoint {
            CGPoint(x: SplashOverlay.Layout.margin + cellWidth * (CGFloat(i) + 0.5), y: rowBase)
        }
    }

    // MARK: 名前と言葉

    private func wordmark(t: Double) -> some View {
        // 名前を眺める間を置いてから、小さく上へ退く
        let shrink = reduceMotion ? 0 : SplashMath.easeSine(SplashMath.at(t, T.eat - 0.6, 0.6))
        return Wordmark(t: t, beats: T.beats, still: reduceMotion)
            .scaleEffect(1 - 0.25 * shrink)
            .frame(maxWidth: .infinity)
            .offset(y: SplashOverlay.Layout.markTop - 14 * shrink)
    }

    /// a から入って b の手前で消える。入りと消えはゆっくり
    private func window(_ t: Double, _ a: Double, _ b: Double, _ fadeIn: Double, _ fadeOut: Double) -> Double {
        SplashMath.easeSine(SplashMath.at(t, a, fadeIn)) * (1 - SplashMath.easeSine(SplashMath.at(t, b - fadeOut, fadeOut)))
    }

    @ViewBuilder private func words(t: Double, layout: Layout) -> some View {
        let phrases: [(LocalizedStringKey, Double, Double, Color)] = [
            ("食べて、", T.eat, T.squat, .ink),
            ("しゃがんで、", T.squat, T.tap, .ink),
            ("連続タップ。", T.tap, T.row - 0.2, .dopa),
        ]
        ForEach(0..<phrases.count, id: \.self) { i in
            let p = phrases[i]
            Text(p.0)
                .font(.label(24, black: true))
                .foregroundStyle(p.3)
                .frame(maxWidth: .infinity)
                .offset(y: layout.stage.y + 44)
                .opacity(window(t, p.1 + 0.1, p.2, 0.5, 0.45))
        }
        Text("1日1回で、1人ずつ。")
            .font(.label(17, black: true))
            .frame(maxWidth: .infinity)
            .offset(y: layout.rowBase + 48)
            .opacity(window(t, T.row + 1.2, T.seat + 0.2, 0.5, 0.5))
        Text("来週には、7人のスクワットマンになる。")
            .font(.label(17, black: true))
            .foregroundStyle(Color.dopa)
            .frame(maxWidth: .infinity)
            .offset(y: layout.rowBase + 76)
            .opacity(window(t, T.glimpse + 0.3, T.seat + 0.2, 0.5, 0.5))
    }

    // MARK: 絵

    private func draw(in ctx: GraphicsContext, layout: Layout, t: Double) {
        let still = reduceMotion

        // 今週の席。左端が今日。1つずつ、間を置いて並ぶ
        let rowOut = SplashMath.easeSine(SplashMath.at(t, T.seat, 0.6))
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let todayWeekday = calendar.component(.weekday, from: RecordDay(.now, calendar: calendar).noon(calendar: calendar)) - 1
        for i in 0..<7 {
            let foot = layout.seat(i)
            let s = SplashMath.easeSine(SplashMath.at(t, T.row + 1.0 + Double(i) * 0.12, 0.35))
            if i == 0 {
                if t < T.seat { SplashPaint.spot(in: ctx, foot: foot, k: Layout.rowK, opacity: s) }
            } else if i == 6 {
                SplashPaint.ticket(in: ctx, foot: foot, k: Layout.rowK, opacity: s * (1 - rowOut))
            } else {
                SplashPaint.futureSpot(in: ctx, foot: foot, k: Layout.rowK, opacity: s * (1 - rowOut))
            }
            let label = i == 0 ? Text("今日").foregroundStyle(Color.dopa)
                : Text(verbatim: symbols[(todayWeekday + i) % 7]).foregroundStyle(Color.mute)
            var lc = ctx
            lc.opacity = SplashMath.easeSine(SplashMath.at(t, T.row + 1.1 + Double(i) * 0.12, 0.35)) * (1 - rowOut)
            lc.draw(label.font(.label(11)), at: CGPoint(x: foot.x, y: foot.y + 16), anchor: .top)
        }
        var pc = ctx
        pc.opacity = SplashMath.easeSine(SplashMath.at(t, T.row + 1.9, 0.4)) * (1 - rowOut)
        pc.draw(Text("休み券").font(.label(10)).foregroundStyle(Color.signal),
                at: CGPoint(x: layout.seat(6).x, y: layout.rowBase + 32), anchor: .top)

        // 明日からの6人が、1人ずつ立って、しゃがんで、いっしょに消える
        if !still {
            for i in 1...5 {
                let a = T.glimpse + Double(i - 1) * 0.15
                let o = SplashMath.easeSine(SplashMath.at(t, a, 0.25)) * (1 - SplashMath.easeSine(SplashMath.at(t, T.glimpse + 1.6, 0.5)))
                guard o > 0 else { continue }
                SplashPaint.figure(in: ctx, foot: layout.seat(i), k: Layout.rowK, squat: SplashMath.dip((t - a - 0.1) / 0.5),
                                   opacity: o * 0.85)
            }
        }

        // やって見せる1人。まん中に大きく立ち、今日の席へ縮んで入って消える
        let appear = SplashMath.easeSine(SplashMath.at(t, T.eat, 0.6))
        let e = still ? (t >= T.row + 0.45 ? 1 : 0) : SplashMath.easeSine(SplashMath.at(t, T.row, 0.9))
        let seat0 = layout.seat(0)
        let k = SplashMath.lerp(Layout.bigK, Layout.rowK, e)
        let foot = CGPoint(x: SplashMath.lerp(layout.stage.x, seat0.x, e),
                           y: SplashMath.lerp(layout.stage.y, seat0.y, e) + (still ? 0 : (1 - appear) * 16))
        let actorOpacity = appear * (1 - SplashMath.easeSine(SplashMath.at(t, T.row + 0.8, 0.4)))
        var depth = 0.0
        let su = (t - T.squat - 0.4) / 1.4
        if !still {
            // 0.6秒で下り、0.2秒とどまり、0.6秒で上る
            if su > 0, su < 1 {
                depth = su < 0.43 ? SplashMath.easeSine(su / 0.43) : su < 0.57 ? 1 : 1 - SplashMath.easeSine((su - 0.57) / 0.43)
            }
        } else if t >= T.squat + 0.4, t < T.tap {
            depth = 1
        }
        if actorOpacity > 0 {
            SplashPaint.figure(in: ctx, foot: foot, k: k, squat: depth, opacity: actorOpacity)
        }

        // 叩く：言葉が出てから、足元から輪とドパの粒
        if !still, t >= T.tapHit {
            let tu = SplashMath.at(t, T.tapHit, 0.9)
            SplashPaint.ring(in: ctx, center: layout.stage, radius: 10 + 70 * SplashMath.easeOut(tu), opacity: 1 - tu)
            for i in 0..<8 {
                let angle = -Double.pi * (0.15 + 0.7 * Double(i) / 7)
                let dist = 30 + 76 * SplashMath.easeOut(tu)
                let c = CGPoint(x: layout.stage.x + cos(angle) * dist, y: layout.stage.y + sin(angle) * dist)
                var gc = ctx
                gc.opacity = 1 - tu
                gc.fill(Path(ellipseIn: CGRect(x: c.x - 4, y: c.y - 4, width: 8, height: 8)), with: .color(.dopa))
            }
        }

        // 今日の席だけが残り、まん中へ寄って大きくなる。息をするように濃淡を繰り返す
        if t >= T.seat {
            let settle = still ? (t >= T.seat + 0.4 ? 1 : 0) : SplashMath.easeSine(SplashMath.at(t, T.seat + 0.2, 0.8))
            let to = CGPoint(x: SplashMath.lerp(seat0.x, layout.stage.x, settle), y: SplashMath.lerp(seat0.y, layout.stage.y, settle))
            let ks = SplashMath.lerp(Layout.rowK, Layout.seatK, settle)
            SplashPaint.spot(in: ctx, foot: to, k: ks, opacity: 0.6 + 0.4 * (0.5 + 0.5 * cos((t - T.seat) * 2 * .pi / 1.8)))
            if !still, t >= T.seatHit {
                let ru = SplashMath.at(t, T.seatHit, 0.8)
                SplashPaint.ring(in: ctx, center: to, radius: 10 + 56 * SplashMath.easeOut(ru), opacity: 1 - ru)
            }
        }
    }
}
