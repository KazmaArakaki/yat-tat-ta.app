import SwiftUI

/// しゃがんだ人形。履歴で記録1件を表す
///
/// 点はスクワット隊（SquatterLayer）の「立つ」「しゃがむ」と同じ。片方だけ直して形がずれないように共有する。
/// animating のあいだは、立つ⇄しゃがむを繰り返す（押した人形）。
struct SquatFigure: View {
    /// しゃがんだ姿の、頭のてっぺんから足先までの高さ
    let height: CGFloat
    let color: Color
    var animating = false

    /// 高さ100の点で描いたしゃがんだ姿の外枠（太い線の幅まで含む）。並べるときの大きさはこれで決める
    static let bounds = CGRect(x: -14, y: -81, width: 52, height: 88)
    /// 描く範囲。立った姿の頭まで入るよう、上に伸ばす。下端はしゃがんだ姿にそろえる
    private static let canvas = CGRect(x: -14, y: -99, width: 52, height: 106)
    /// 立つ⇄しゃがむの1往復
    private static let period = 0.8

    var body: some View {
        let k = height / Self.bounds.height
        Color.clear
            .frame(width: Self.bounds.width * k, height: height)
            .overlay(alignment: .bottom) {
                TimelineView(.animation(paused: !animating)) { timeline in
                    Canvas { context, _ in
                        draw(in: &context, k: k, squat: animating ? Self.depth(at: timeline.date) : 1)
                    }
                }
                .frame(width: Self.canvas.width * k, height: Self.canvas.height * k)
            }
    }

    /// しゃがみの深さ。1がしゃがんだ姿、0が立った姿。下りを速く、上りをゆっくり見せるため sin を少し尖らせる
    private static func depth(at date: Date) -> CGFloat {
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
        let wave = (1 - cos(2 * .pi * t)) / 2
        return CGFloat(1 - pow(1 - wave, 2))
    }

    private func draw(in context: inout GraphicsContext, k: CGFloat, squat: CGFloat) {
        let a = SquatterLayer.stand, b = SquatterLayer.squat
        let mix = { (p: CGPoint, q: CGPoint) in CGPoint(x: p.x + (q.x - p.x) * squat, y: p.y + (q.y - p.y) * squat) }
        let legs = zip(a.legs, b.legs).map(mix)
        let arm = zip(a.arm, b.arm).map(mix)
        let head = mix(a.head, b.head)
        context.translateBy(x: -Self.canvas.minX * k, y: -Self.canvas.minY * k)
        context.scaleBy(x: k, y: k)
        var limbs = Path()
        limbs.addLines(legs)
        limbs.addLines(arm)
        let round = { (w: CGFloat) in StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round) }
        context.stroke(limbs, with: .color(.onGold), style: round(15))
        context.stroke(limbs, with: .color(color), style: round(9))
        context.fill(Path(ellipseIn: CGRect(x: head.x - 12, y: head.y - 12, width: 24, height: 24)), with: .color(.onGold))
        context.fill(Path(ellipseIn: CGRect(x: head.x - 8.5, y: head.y - 8.5, width: 17, height: 17)), with: .color(color))
    }

    /// 人形の高さ。面積をドパに比例させる（高さは平方根）。14〜46pt
    static func height(dopa: Int) -> CGFloat {
        min(46, max(14, 6.5 * sqrt(CGFloat(dopa))))
    }
}
