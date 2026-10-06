import SwiftUI

/// しゃがんだ人形。履歴で記録1件を表す
///
/// 点はスクワット隊（SquatterLayer）の「しゃがむ」と同じ。片方だけ直して形がずれないように共有する。
struct SquatFigure: View {
    /// 頭のてっぺんから足先までの高さ
    let height: CGFloat
    let color: Color

    /// 高さ100の点で描いたときの外枠（太い線の幅まで含む）
    static let bounds = CGRect(x: -14, y: -81, width: 52, height: 88)

    var body: some View {
        let k = height / Self.bounds.height
        Canvas { context, _ in
            let joints = SquatterLayer.squat
            context.translateBy(x: -Self.bounds.minX * k, y: -Self.bounds.minY * k)
            context.scaleBy(x: k, y: k)
            var limbs = Path()
            for points in [joints.legs, joints.arm] {
                limbs.addLines(points)
            }
            let round = { (w: CGFloat) in StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round) }
            context.stroke(limbs, with: .color(.onGold), style: round(15))
            context.stroke(limbs, with: .color(color), style: round(9))
            context.fill(Path(ellipseIn: CGRect(x: joints.head.x - 12, y: joints.head.y - 12, width: 24, height: 24)), with: .color(.onGold))
            context.fill(Path(ellipseIn: CGRect(x: joints.head.x - 8.5, y: joints.head.y - 8.5, width: 17, height: 17)), with: .color(color))
        }
        .frame(width: Self.bounds.width * k, height: height)
    }

    /// 人形の高さ。面積をドパに比例させる（高さは平方根）。14〜46pt
    static func height(dopa: Int) -> CGFloat {
        min(46, max(14, 6.5 * sqrt(CGFloat(dopa))))
    }
}
