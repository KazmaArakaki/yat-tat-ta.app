import SwiftUI

/// 押した人形。その日の列と、記録1件
struct HistorySelection: Equatable {
    let day: History.Day
    let entry: History.Entry
}

/// 履歴のグラフ。横に記録日、縦にその日の時刻（午前4時から翌朝4時、上ほど遅い）
///
/// 記録1件をしゃがんだ人形1つで置き、背景に日ごとのドパと7日移動平均の面を重ねる。
/// 面は ScrollView の後ろの Canvas 1枚に、見えている範囲だけ描く。
/// 1年分を1枚の絵にすると幅が1万pt を超え、メモリを食うから。
struct HistoryChart: View {
    let history: History
    @Binding var selected: HistorySelection?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scrollX: CGFloat = 0
    @State private var appeared = false

    /// 1画面に見える日数
    static let visibleDays = History.minDays
    private static let axisWidth: CGFloat = 38
    private static let dateBand: CGFloat = 34
    private static let top: CGFloat = 10
    /// 時刻の目盛り。4時起点で並べた時（24 は 0時、27 は 3時）
    private static let hours = [6, 9, 12, 15, 18, 21, 24, 27]

    var body: some View {
        GeometryReader { geo in
            let dayWidth = (geo.size.width - Self.axisWidth) / CGFloat(Self.visibleDays)
            let plot = geo.size.height - Self.top - Self.dateBand
            HStack(spacing: 0) {
                axis(plot: plot)
                ZStack(alignment: .topLeading) {
                    background(dayWidth: dayWidth, plot: plot)
                    ScrollView(.horizontal) {
                        LazyHStack(spacing: 0) {
                            ForEach(Array(history.days.enumerated()), id: \.element.id) { index, day in
                                column(day, order: history.days.count - 1 - index, width: dayWidth, plot: plot)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .defaultScrollAnchor(.trailing)
                    .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.x } action: { _, x in scrollX = x }
                }
                .clipped()
            }
        }
        .onAppear { appeared = true }
    }

    private func y(_ minute: Int, plot: CGFloat) -> CGFloat {
        Self.top + plot - CGFloat(minute) / (24 * 60) * plot
    }

    // MARK: - 左の時刻

    private func axis(plot: CGFloat) -> some View {
        ZStack(alignment: .topTrailing) {
            ForEach(Self.hours, id: \.self) { h in
                Text(verbatim: "\(h % 24):00")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.mute)
                    .position(x: Self.axisWidth / 2, y: y((h - RecordDay.boundaryHour) * 60, plot: plot))
            }
        }
        .frame(width: Self.axisWidth)
        .accessibilityHidden(true)
    }

    // MARK: - 背景（時刻の線、今日の列、面グラフ）

    private func background(dayWidth: CGFloat, plot: CGFloat) -> some View {
        Canvas { context, size in
            let days = history.days
            let floor = Self.top + plot
            let x = { (i: Int) in CGFloat(i) * dayWidth + dayWidth / 2 - scrollX }

            // 今日の列
            if let last = days.indices.last {
                context.fill(Path(CGRect(x: x(last) - dayWidth / 2, y: 0, width: dayWidth, height: floor)),
                             with: .color(.dopaSoft.opacity(0.8)))
            }
            for h in Self.hours {
                let yy = y((h - RecordDay.boundaryHour) * 60, plot: plot)
                var line = Path()
                line.move(to: CGPoint(x: 0, y: yy))
                line.addLine(to: CGPoint(x: size.width, y: yy))
                context.stroke(line, with: .color(.rule),
                               style: StrokeStyle(lineWidth: h == 12 || h == 24 ? 1.2 : 0.7, dash: h == 24 ? [] : [2, 3]))
            }

            // 見えている列と、曲線をつなぐための前後2列
            guard !days.isEmpty else { return }
            let first = max(0, Int(scrollX / dayWidth) - 2)
            let last = min(days.count - 1, Int((scrollX + size.width) / dayWidth) + 2)
            guard first <= last else { return }
            let scale = CGFloat(max(10, history.peak)) * 1.15
            let v = { (value: Double) in floor - CGFloat(value) / scale * plot }
            for (value, color, opacity) in [
                ({ (d: History.Day) in Double(d.dopa) }, Color.dopa, 0.14),
                ({ (d: History.Day) in d.average }, Color.signal, 0.1),
            ] {
                var points = (first...last).map { CGPoint(x: x($0), y: v(value(days[$0]))) }
                // 両端の日は、列の端まで同じ高さで伸ばす
                if first == 0 { points.insert(CGPoint(x: x(0) - dayWidth / 2, y: points[0].y), at: 0) }
                if last == days.count - 1 { points.append(CGPoint(x: x(last) + dayWidth / 2, y: points[points.count - 1].y)) }
                let curve = Self.smooth(points, floor: floor)
                var area = curve
                area.addLine(to: CGPoint(x: points[points.count - 1].x, y: floor))
                area.addLine(to: CGPoint(x: points[0].x, y: floor))
                area.closeSubpath()
                context.fill(area, with: .color(color.opacity(opacity)))
                context.stroke(curve, with: .color(color), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
            }

            var base = Path()
            base.move(to: CGPoint(x: 0, y: floor))
            base.addLine(to: CGPoint(x: size.width, y: floor))
            context.stroke(base, with: .color(.ink), lineWidth: 2)
        }
        .accessibilityHidden(true)
    }

    /// 点を通るなめらかな線（Catmull-Rom を3次ベジェに直す）
    ///
    /// 制御点が底より下へ出ると、0ドパの日に線が底を突き抜ける。底で止める。
    private static func smooth(_ p: [CGPoint], floor: CGFloat) -> Path {
        var path = Path()
        path.move(to: p[0])
        for i in 0..<(p.count - 1) {
            let p0 = p[max(i - 1, 0)], p1 = p[i], p2 = p[i + 1], p3 = p[min(i + 2, p.count - 1)]
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: min(floor, p1.y + (p2.y - p0.y) / 6))
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: min(floor, p2.y - (p3.y - p1.y) / 6))
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
        return path
    }

    // MARK: - 日の列（人形と日付）

    /// order: 今日から何日前か
    private func column(_ day: History.Day, order: Int, width: CGFloat, plot: CGFloat) -> some View {
        let isToday = day.day == history.today
        let date = day.day.noon()
        return ZStack(alignment: .topLeading) {
            if day.usedRestPass {
                RoundedRectangle(cornerRadius: 3).fill(Color.signal)
                    .frame(width: 11, height: 14)
                    .position(x: width / 2, y: y(10 * 60, plot: plot))
                    .accessibilityHidden(true)
            }
            ForEach(Array(day.entries.enumerated()), id: \.element.id) { index, entry in
                figure(entry, in: day, order: order, index: index)
                    .position(x: width / 2, y: y(entry.minute, plot: plot))
            }
            VStack(spacing: 1) {
                // 月の初めと左端の列だけ月を添える。ほかは日の数字だけ
                Text(verbatim: day.day.value % 100 == 1 || day.id == history.days.first?.id
                     ? "\(day.day.value / 100 % 100)/\(day.day.value % 100)" : "\(day.day.value % 100)")
                    .font(.number(12))
                    .foregroundStyle(isToday ? Color.dopa : Color.ink)
                Group {
                    if isToday { Text("今日") } else { Text(date, format: .dateTime.weekday(.narrow)) }
                }
                .font(.label(9))
                .foregroundStyle(isToday ? Color.dopa : Color.mute)
            }
            .frame(width: width)
            .position(x: width / 2, y: Self.top + plot + Self.dateBand / 2)
            .accessibilityHidden(true)
        }
        .frame(width: width)
        .frame(maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Self.dayLabel(day, today: history.today))
    }

    private func figure(_ entry: History.Entry, in day: History.Day, order: Int, index: Int) -> some View {
        let height = SquatFigure.height(dopa: entry.dopa)
        let isSelected = selected?.entry.id == entry.id
        // 開いた直後に見えている7日分ほどだけ、ずらして弾ませる
        let delay = order < 8 ? Double(7 - order) * 0.05 + Double(index) * 0.03 : 0
        return Button {
            selected = HistorySelection(day: day, entry: entry)
        } label: {
            // 押した人形は、立つ⇄しゃがむを繰り返す。ひかえめモードではしゃがんだまま
            SquatFigure(height: height, color: entry.bonusDopa > 0 ? .dopa : .gold, animating: isSelected && !reduceMotion)
                .overlay {
                    if isSelected {
                        Circle()
                            .strokeBorder(Color.ink, style: StrokeStyle(lineWidth: 2, dash: [3, 2]))
                            .frame(width: height * 1.25, height: height * 1.25)
                    }
                }
                // 押しやすさのため、当たりを 30pt 四方以上にとる
                .frame(minWidth: 30, minHeight: 30)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .scaleEffect(appeared || reduceMotion ? 1 : 0.2)
        .opacity(appeared || reduceMotion ? 1 : 0)
        .animation(reduceMotion ? nil : .spring(duration: 0.4, bounce: 0.5).delay(delay), value: appeared)
        .accessibilityLabel(Self.entryLabel(entry))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - 読み上げ

    static func dayLabel(_ day: History.Day, today: RecordDay) -> Text {
        let date = Text(day.day.noon(), format: .dateTime.month().day().weekday(.wide))
        let average = Int(day.average.rounded())
        if day.usedRestPass {
            return Text("\(date)、休み券を使った日、7日平均\(average)")
        }
        return Text("\(date)、\(day.entries.count)件、\(day.dopa)ドパ、7日平均\(average)")
    }

    static func entryLabel(_ entry: History.Entry) -> Text {
        let time = Text(entry.startedAt, format: .dateTime.hour().minute())
        if entry.bonusDopa > 0 {
            return Text("\(time)、\(entry.reps)回、フィーバー\(entry.bonusDopa)ドパ")
        }
        return Text("\(time)、\(entry.reps)回")
    }
}
