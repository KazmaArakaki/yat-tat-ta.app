import SwiftUI

/// DPW と DT のカード。叩くたびに、どちらも1ずつ増える
struct TotalsCards: View {
    let dopaPerWeek: Int
    let previousWindow: Int
    let bestWindow: Int?
    let dopaTotal: Int

    var body: some View {
        HStack(spacing: 12) {
            dpw
            dt
        }
    }

    private var beatsBest: Bool { bestWindow.map { dopaPerWeek > $0 } ?? false }

    private var dpw: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("DPW").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(Color.mute)
            Text(verbatim: "\(dopaPerWeek)")
                .font(.number(30))
                .foregroundStyle(beatsBest ? Color.dopa : Color.ink)
                .contentTransition(.numericText(value: Double(dopaPerWeek)))
            if let bestWindow {
                Text("前の7日 \(previousWindow)　ベスト \(bestWindow)")
                    .font(.label(11)).foregroundStyle(Color.mute)
                if beatsBest {
                    Text("ベスト更新中")
                        .font(.label(10, black: true))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.gold, in: .capsule)
                        .foregroundStyle(Color.onGold)
                }
            } else {
                Text("比べるのは8日目から").font(.label(11)).foregroundStyle(Color.mute)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .padding(12)
        .toyCard()
    }

    private var dt: some View {
        let next = Milestone.dopaTotalSteps.first { $0 > dopaTotal }
        let previous = Milestone.dopaTotalSteps.last { $0 <= dopaTotal } ?? 0
        return VStack(alignment: .leading, spacing: 2) {
            Text("DT").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(Color.mute)
            Text(verbatim: "\(dopaTotal)")
                .font(.number(30))
                .contentTransition(.numericText(value: Double(dopaTotal)))
            if let next {
                Text("次の節目 \(next.formatted())").font(.label(11)).foregroundStyle(Color.mute)
                // ひとつ前の節目から次の節目までの進み具合
                GeometryReader { g in
                    Capsule().fill(Color.rule)
                        .overlay(alignment: .leading) {
                            Capsule().fill(Color.dopa)
                                .frame(width: g.size.width * CGFloat(dopaTotal - previous) / CGFloat(next - previous))
                        }
                }
                .frame(height: 5)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .padding(12)
        .toyCard()
    }
}
