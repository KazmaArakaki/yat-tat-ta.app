import SwiftUI

/// 起動したときに、ホームの上に重ねる幕。ロゴではなく、いまの連続を人形の隊列で見せる
///
/// 出すのは、起動したときと、その日いちばん初めに開いたとき。インストールして最初の1回だけは、
/// はじめての幕（IntroSplash）にする。見本は docs/ui/components/splash（splash.js と同じ秒にそろえる）。
struct Splash: Identifiable, Equatable {
    enum Kind: Equatable {
        /// ふつうの幕。1.65秒
        case regular
        /// はじめての幕。14.0秒
        case intro
    }

    let id = UUID()
    let kind: Kind
    let streak: Ledger.Streak
    let lineup: Lineup

    init(kind: Kind, streak: Ledger.Streak, today: RecordDay, calendar: Calendar = .current) {
        self.kind = kind
        self.streak = streak
        lineup = Lineup(streak: streak, today: today, firstWeekday: calendar.firstWeekday, calendar: calendar)
    }

    /// 次の1回で連続の節目に届くか
    var nextIsMilestone: Bool {
        !streak.doneToday && streak.current > 0 && Milestone.streak(reaching: streak.nextCount) != nil
    }
}

// MARK: - ふつうの幕

/// ふつうの幕。名前の3拍と、古い日から今日の席へ流れるしゃがみの波。最後に数だけが帯へ飛ぶ
struct SplashOverlay: View {
    let splash: Splash
    /// 帯の日数の数字の位置（画面全体の座標）。飛ぶ先
    let target: CGRect?
    var beats: ([FeelEngine.Beat]) -> Void = { _ in }
    var finish: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @State private var clock = SplashClock()

    /// 時刻（秒）。ふつうの場合
    struct Timing {
        var waveStart = 0.15
        var waveSpan = 0.55
        var squat = 0.34
        var beats = [0.15, 0.45, 0.75]
        var seat = 0.75
        var handoff = 1.25
        var end = 1.65

        static let normal = Timing()
        /// ひかえめモード。置いて、溶かすだけ。振動の3拍は変えない
        static let still = Timing(seat: 0, handoff: 0.9, end: 1.15)

        /// VoiceOver は読み終わるまで幕を残す
        func holding(for voiceOver: Bool) -> Timing {
            guard voiceOver else { return self }
            var t = self
            t.handoff = max(handoff, 4.0)
            t.end = t.handoff + (end - handoff)
            return t
        }
    }

    private var timing: Timing { (reduceMotion ? Timing.still : Timing.normal).holding(for: voiceOver) }

    var body: some View {
        let tm = timing
        TimelineView(.animation(paused: clock.origin == nil)) { context in
            let t = clock.time(at: context.date)
            let hu = SplashMath.at(t, tm.handoff, tm.end - tm.handoff)
            let fade = 1 - SplashMath.clamp(hu * 2)
            ZStack(alignment: .topLeading) {
                Color.paper.opacity(1 - SplashMath.clamp(hu * 2.5)).ignoresSafeArea()
                GeometryReader { geo in
                    let layout = Layout(size: geo.size, lineup: splash.lineup)
                    ZStack(alignment: .topLeading) {
                        Canvas { ctx, _ in draw(in: ctx, layout: layout, t: t, tm: tm) }
                            .opacity(fade)
                        Wordmark(t: t, beats: tm.beats, still: reduceMotion)
                            .frame(maxWidth: .infinity)
                            .offset(y: Layout.markTop)
                            .opacity(fade)
                        if splash.lineup.hidden > 0 {
                            Text("＋\(splash.lineup.hidden)日")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.mute)
                                .offset(x: Layout.margin, y: layout.gridTopEdge - 22)
                                .opacity(fade)
                        }
                        SplashNumber(prefix: prefix, number: splash.streak.current > 0 ? splash.streak.current : 1, suffix: suffix,
                                     t: t, handoff: tm.handoff, end: tm.end, target: target, still: reduceMotion)
                            .offset(x: Layout.margin, y: layout.infoTop)
                        line
                            .opacity(SplashMath.clamp((t - tm.seat) / 0.18) * fade)
                            .offset(x: Layout.margin, y: layout.infoTop + 102
                                    + (reduceMotion ? 0 : (1 - SplashMath.easeOut(SplashMath.at(t, tm.seat, 0.25))) * 6))
                    }
                }
            }
        }
        .contentShape(.rect)
        .onTapGesture { skip(tm) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .onAppear {
            clock.start()
            beats(tm.beats.enumerated().map { FeelEngine.Beat(at: $1, strong: $0 == 2) })
        }
        .task(id: clock.origin) {
            guard clock.origin != nil else { return }
            #if DEBUG
            // 止めて見ているあいだは消さない
            if SplashClock.frozen != nil { return }
            #endif
            try? await Task.sleep(for: .seconds(max(0, tm.end - clock.time(at: .now))))
            guard !Task.isCancelled else { return }
            finish()
        }
    }

    /// 叩いたら、その場で引き継ぎへ。まだ鳴っていない拍は鳴らさない
    private func skip(_ tm: Timing) {
        guard clock.time(at: .now) < tm.handoff else { return }
        beats([])
        clock.jump(to: tm.handoff)
    }

    // MARK: 文言

    private var prefix: LocalizedStringKey? {
        guard splash.streak.current == 0 else { return nil }
        return splash.streak.best > 0 ? "今日の1回で" : "最初の1回で"
    }

    private var suffix: LocalizedStringKey { splash.streak.current > 0 ? "日連続" : "日目" }

    private var line: some View {
        HStack(spacing: 8) {
            lineText
                .font(.label(15, black: true))
                .foregroundStyle(splash.streak.doneToday ? Color.dopa : Color.ink)
            if splash.nextIsMilestone {
                Text("節目")
                    .font(.label(11, black: true))
                    .foregroundStyle(Color.onGold)
                    .padding(.horizontal, 8).padding(.vertical, 1)
                    .background(Color.gold, in: .capsule)
                    .overlay(Capsule().strokeBorder(Color.onGold, lineWidth: 2))
            }
        }
    }

    /// 帯と同じ考え方の一言。失ったものではなく、次の1回で起きることを書く
    private var lineText: Text {
        let s = splash.streak
        if s.doneToday { return Text("✓ 今日のぶんは済み") }
        if s.current > 0 { return Text("今日の1回で\(s.nextCount)日目") }
        if s.best > 0 { return Text("最長記録 \(s.best)日") }
        return Text("食べて、しゃがんで、連続タップ")
    }

    private var accessibilityText: Text {
        let s = splash.streak
        let head = s.current > 0 ? Text("\(s.current)日連続") : Text("最初の1回で1日目")
        return Text(verbatim: "Yat Tat Ta. ") + head + Text(verbatim: ". ") + lineText
    }

    // MARK: 隊列

    /// 置き方。安全領域の中の座標
    struct Layout {
        static let margin: CGFloat = 28
        static let markTop: CGFloat = 28
        let size: CGSize
        let infoTop: CGFloat
        let gridTop: CGFloat
        let gridBottom: CGFloat
        let cellWidth: CGFloat
        let rowHeight: CGFloat
        /// 点1つぶんの大きさ
        let k: CGFloat
        let rows: Int
        let seatOnly: Bool

        init(size: CGSize, lineup: Lineup) {
            self.size = size
            infoTop = size.height * 0.66
            gridTop = 104
            gridBottom = infoTop - 28
            cellWidth = (size.width - Self.margin * 2) / CGFloat(Lineup.columns)
            rows = max(1, lineup.rows)
            seatOnly = lineup.isSeatOnly
            rowHeight = min(64, (gridBottom - gridTop) / CGFloat(rows))
            k = seatOnly ? 1.3 : min(rowHeight * 0.86 / 106, cellWidth * 0.95 / 52)
        }

        /// i 番目のマスの足元のまん中（床の印の中心）
        func foot(_ i: Int) -> CGPoint {
            if seatOnly { return CGPoint(x: size.width / 2, y: gridBottom - 10) }
            let col = i % Lineup.columns, row = i / Lineup.columns
            return CGPoint(x: Self.margin + cellWidth * (CGFloat(col) + 0.5),
                           y: gridBottom - CGFloat(rows - 1 - row) * rowHeight - 4)
        }

        var gridTopEdge: CGFloat { gridBottom - CGFloat(rows) * rowHeight }
    }

    private func draw(in ctx: GraphicsContext, layout: Layout, t: Double, tm: Timing) {
        let cells = splash.lineup.cells
        let pastCount = cells.filter { $0 == .past }.count
        var pastIndex = 0
        let su = t - tm.seat
        for (i, cell) in cells.enumerated() {
            let foot = layout.foot(i), k = layout.k
            switch cell {
            case .blank:
                break
            case .past:
                SplashPaint.shadow(in: ctx, foot: foot, k: k)
                var d: Double = 0
                if !reduceMotion {
                    let frac = pastCount > 1 ? Double(pastIndex) / Double(pastCount - 1) : 1
                    let s = tm.waveStart + tm.waveSpan * frac - tm.squat * 0.6
                    d = SplashMath.dip((t - s) / tm.squat)
                }
                SplashPaint.figure(in: ctx, foot: foot, k: k, squat: d)
                pastIndex += 1
            case .rest:
                SplashPaint.ticket(in: ctx, foot: foot, k: k)
            case .seat, .today:
                let pulse = su < 0 ? 0.55 : reduceMotion ? 1 : 0.55 + 0.45 * (0.5 + 0.5 * cos(su * 2 * .pi / 1.1))
                SplashPaint.spot(in: ctx, foot: foot, k: k, opacity: cell == .seat ? pulse : 1)
                if cell == .today {
                    let d = reduceMotion || su < 0 ? 0 : SplashMath.dip(su / 0.3) + SplashMath.dip((su - 0.3) / 0.3)
                    SplashPaint.figure(in: ctx, foot: foot, k: k, squat: d)
                }
                if su >= 0, !reduceMotion {
                    let ru = SplashMath.clamp(su / 0.5)
                    SplashPaint.ring(in: ctx, center: foot, radius: 10 + 40 * SplashMath.easeOut(ru) * (layout.seatOnly ? 1.6 : 1),
                                     opacity: 1 - ru)
                }
            }
        }
    }
}

// MARK: - 共有する部品

/// 時計。表示を始めた時刻からの秒。叩いて飛ばすときは、始めた時刻をずらす
struct SplashClock {
    private(set) var origin: Date?

    mutating func start() { if origin == nil { origin = .now } }

    mutating func jump(to t: Double) { origin = Date.now.addingTimeInterval(-t) }

    func time(at date: Date) -> Double {
        #if DEBUG
        if let frozen = Self.frozen { return frozen }
        #endif
        guard let origin else { return 0 }
        return date.timeIntervalSince(origin)
    }

    #if DEBUG
    /// 見本の確認用。起動引数 `-splashAt 1.0` で、その秒に止めて見る
    static let frozen: Double? = {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-splashAt"), i + 1 < args.count else { return nil }
        return Double(args[i + 1])
    }()
    #endif
}

enum SplashMath {
    static func clamp(_ x: Double) -> Double { min(1, max(0, x)) }
    static func at(_ t: Double, _ start: Double, _ duration: Double) -> Double { clamp((t - start) / duration) }
    static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }
    static func easeOut(_ x: Double) -> Double { 1 - pow(1 - clamp(x), 3) }
    static func easeInOut(_ x: Double) -> Double {
        let x = clamp(x)
        return x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2
    }
    /// ゆっくり入って、ゆっくり止まる
    static func easeSine(_ x: Double) -> Double { (1 - cos(.pi * clamp(x))) / 2 }

    /// しゃがみの深さ。下りを速く（4割）、上りをゆっくり（6割）
    static func dip(_ u: Double) -> Double {
        guard u > 0, u < 1 else { return 0 }
        return u < 0.4 ? easeOut(u / 0.4) : 1 - easeInOut((u - 0.4) / 0.6)
    }
}

/// 隊列の絵。点は人形と同じ（足元が原点、上が負、点1つぶんが k）
enum SplashPaint {
    static func figure(in ctx: GraphicsContext, foot: CGPoint, k: CGFloat, squat: Double, opacity: Double = 1) {
        var ctx = ctx
        ctx.opacity = opacity
        // 人形の点は、かかと（0,0）とつま先（12,0）。足元のまん中を foot に合わせる
        SquatFigure.draw(in: ctx, foot: CGPoint(x: foot.x - 6 * k, y: foot.y), k: k, squat: squat, color: .gold)
    }

    /// 人形の足元の影。今日の席の印と同じ位置に落とし、印が「人の立つ場所」だと読めるようにする
    static func shadow(in ctx: GraphicsContext, foot: CGPoint, k: CGFloat) {
        ctx.fill(Path(ellipseIn: CGRect(x: foot.x - 20 * k, y: foot.y + k - 6 * k, width: 40 * k, height: 12 * k)),
                 with: .color(Color(red: 0.11, green: 0.1, blue: 0.09).opacity(0.14)))
    }

    /// 今日の席。人形のいない床の印に、上から薄い光が差している
    static func spot(in ctx: GraphicsContext, foot: CGPoint, k: CGFloat, opacity: Double = 1) {
        var ctx = ctx
        ctx.opacity = opacity
        var cone = Path()
        cone.move(to: CGPoint(x: foot.x - 10 * k, y: foot.y - 112 * k))
        cone.addLine(to: CGPoint(x: foot.x + 10 * k, y: foot.y - 112 * k))
        cone.addLine(to: CGPoint(x: foot.x + 26 * k, y: foot.y))
        cone.addLine(to: CGPoint(x: foot.x - 26 * k, y: foot.y))
        cone.closeSubpath()
        ctx.fill(cone, with: .linearGradient(
            Gradient(colors: [Color.dopa.opacity(0.32), Color.dopa.opacity(0)]),
            startPoint: CGPoint(x: foot.x, y: foot.y), endPoint: CGPoint(x: foot.x, y: foot.y - 112 * k)))
        let disc = Path(ellipseIn: CGRect(x: foot.x - 24 * k, y: foot.y - 7.5 * k, width: 48 * k, height: 15 * k))
        ctx.fill(disc, with: .color(.dopa))
        ctx.stroke(disc, with: .color(.onGold), lineWidth: 3.5 * k)
        ctx.fill(Path(ellipseIn: CGRect(x: foot.x - 14 * k, y: foot.y - 4.1 * k, width: 22 * k, height: 5.2 * k)),
                 with: .color(.white.opacity(0.35)))
    }

    /// 明日からの席。床の印の輪郭だけ
    static func futureSpot(in ctx: GraphicsContext, foot: CGPoint, k: CGFloat, opacity: Double = 1) {
        var ctx = ctx
        ctx.opacity = opacity
        ctx.stroke(Path(ellipseIn: CGRect(x: foot.x - 21 * k, y: foot.y - 6.5 * k, width: 42 * k, height: 13 * k)),
                   with: .color(.mute), style: StrokeStyle(lineWidth: 3 * k, dash: [5 * k, 5 * k]))
    }

    /// 休み券の日。人形の代わりに青い札
    static func ticket(in ctx: GraphicsContext, foot: CGPoint, k: CGFloat, opacity: Double = 1) {
        var ctx = ctx
        ctx.opacity = opacity
        let card = Path(roundedRect: CGRect(x: foot.x - 15 * k, y: foot.y - 50 * k, width: 30 * k, height: 38 * k), cornerRadius: 6 * k)
        ctx.fill(card, with: .color(.signal))
        ctx.stroke(card, with: .color(.onGold), lineWidth: 4 * k)
        var dots = Path()
        dots.move(to: CGPoint(x: foot.x - 9 * k, y: foot.y - 31 * k))
        dots.addLine(to: CGPoint(x: foot.x + 9 * k, y: foot.y - 31 * k))
        ctx.stroke(dots, with: .color(.white.opacity(0.8)), style: StrokeStyle(lineWidth: 3 * k, dash: [2 * k, 3 * k]))
    }

    /// 床の上に広がる輪
    static func ring(in ctx: GraphicsContext, center: CGPoint, radius: CGFloat, opacity: Double) {
        guard opacity > 0 else { return }
        var ctx = ctx
        ctx.opacity = opacity
        ctx.stroke(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius * 0.3, width: radius * 2, height: radius * 0.6)),
                   with: .color(.dopa), lineWidth: 3)
    }
}

/// 名前。「Yat」「Tat」「Ta」が1語ずつ落ちて、着地でつぶれる
struct Wordmark: View {
    let t: Double
    let beats: [Double]
    let still: Bool

    var body: some View {
        HStack(spacing: 9) {
            word("Yat", 0)
            word("Tat", 1)
            word("Ta", 2).foregroundStyle(Color.dopa)
        }
        .font(.system(size: 30, weight: .black, design: .rounded))
        .accessibilityHidden(true)
    }

    private func word(_ s: String, _ i: Int) -> some View {
        let u = t - beats[i]
        let fall = SplashMath.clamp(u / 0.1)
        let v = u - 0.1
        let sq = still || v < 0 ? 0 : exp(-6.5 * v) * cos(14 * v)
        return Text(verbatim: s)
            .scaleEffect(x: 1 + 0.1 * sq, y: 1 - 0.22 * sq, anchor: .bottom)
            .offset(y: still ? 0 : (1 - SplashMath.easeOut(fall)) * -16)
            .opacity(u < 0 ? 0 : still ? SplashMath.clamp(u / 0.15) : 1)
    }
}

/// 大きな数と、その前後の言葉。引き継ぎで、数だけが帯の数の位置へ縮みながら飛ぶ
struct SplashNumber: View {
    let prefix: LocalizedStringKey?
    let number: Int
    let suffix: LocalizedStringKey
    let t: Double
    let handoff: Double
    let end: Double
    let target: CGRect?
    let still: Bool
    var opacity: Double = 1

    @State private var source: CGRect?

    var body: some View {
        let hu = SplashMath.at(t, handoff, end - handoff)
        let e = SplashMath.easeInOut(hu)
        let words = (1 - SplashMath.clamp(hu * 3)) * opacity
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            if let prefix { Text(prefix).font(.label(18, black: true)).opacity(words) }
            numberText
                // 置き場所だけを取り、見える数は上に重ねて飛ばす（測る位置が飛ぶ動きでずれないように）
                .opacity(0)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { source = $0 }
                .overlay(alignment: .bottomLeading) {
                    flying(e: e, hu: hu)
                }
            Text(suffix).font(.label(18, black: true)).opacity(words)
        }
        .foregroundStyle(Color.ink)
    }

    private var numberText: some View {
        Text(verbatim: "\(number)")
            .font(.number(88))
            .foregroundStyle(Color.dopa)
            .fixedSize()
    }

    @ViewBuilder private func flying(e: Double, hu: Double) -> some View {
        if still || target == nil || source == nil {
            numberText.opacity(opacity * (still ? 1 - hu : t >= handoff ? 1 - hu : 1))
        } else if let target, let source {
            let s = target.height / source.height
            numberText
                .scaleEffect(SplashMath.lerp(1, s, e), anchor: .bottomLeading)
                .offset(x: (target.minX - source.minX) * e, y: (target.maxY - source.maxY) * e)
                .opacity(opacity)
        }
    }
}
