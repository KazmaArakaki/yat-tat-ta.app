// SNS の動画の左右の余白に並べる、スクワットマンの隊列を描く
//
// compose_reel.py から呼ぶ。1回の動きぶんの絵を PNG の連番で書き出し、動画の側で繰り返す。
// 関節の位置と色は ios/YatTatTa/Home/SquatStageView.swift の SquatterLayer と同じ。人形を直したら、ここも直す。
//
//     swift Design/reel_squad.swift <書き出す先> <幅> <高さ> <姿> <1回の枚数>
//
// 姿は lie（寝ている。1枚だけ）か squat（立つ⇄しゃがむ）。

import AppKit
import CoreGraphics

struct Joints {
    var legs: [CGPoint]
    var arm: [CGPoint]
    var head: CGPoint

    func mixed(with other: Joints, _ t: CGFloat) -> Joints {
        func mix(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t) }
        return Joints(legs: zip(legs, other.legs).map(mix), arm: zip(arm, other.arm).map(mix), head: mix(head, other.head))
    }
}

let stand = Joints(
    legs: [.init(x: 12, y: 0), .init(x: 0, y: 0), .init(x: 0, y: -21), .init(x: 0, y: -42), .init(x: 0, y: -72)],
    arm: [.init(x: 0, y: -72), .init(x: 4, y: -58), .init(x: 6, y: -46)],
    head: .init(x: 2, y: -86))
let squat = Joints(
    legs: [.init(x: 12, y: 0), .init(x: 0, y: 0), .init(x: 15, y: -15), .init(x: -7, y: -25), .init(x: 3, y: -55)],
    arm: [.init(x: 3, y: -55), .init(x: 17, y: -55), .init(x: 31, y: -56)],
    head: .init(x: 7, y: -69))
let lie = Joints(
    legs: [.init(x: 44, y: -14), .init(x: 40, y: -7), .init(x: 19, y: -7), .init(x: -2, y: -7), .init(x: -32, y: -7)],
    arm: [.init(x: -32, y: -7), .init(x: -18, y: -3), .init(x: -6, y: -3)],
    head: .init(x: -46, y: -12))

func color(_ hex: Int) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}
let ink = color(0x1C1916)
let palette = [color(0xE9A800), color(0xE5337A), color(0x2F79F7)]

let args = CommandLine.arguments
let out = URL(fileURLWithPath: args[1])
let width = Int(args[2])!, height = Int(args[3])!
let sleeping = args[4] == "lie"
let frames = sleeping ? 1 : Int(args[5])!

// 2列を互い違いに並べる。人形の高さ（足首から頭まで）は約 90 × k
let k: CGFloat = 1.05
let columns: [CGFloat] = [CGFloat(width) * 0.3, CGFloat(width) * 0.72]
let rowStep: CGFloat = 118
let rows = Int((CGFloat(height) - 40) / rowStep)

try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
for frame in 0..<frames {
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    // 左上を原点に、下を正にする（関節の点は上がマイナス）
    context.translateBy(x: 0, y: CGFloat(height))
    context.scaleBy(x: 1, y: -1)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    var index = 0
    for row in 0..<rows {
        for (c, x) in columns.enumerated() {
            let ankle = CGPoint(x: x - (sleeping ? 10 : 0), y: 40 + rowStep * CGFloat(row + 1) - (c == 1 ? rowStep / 2 : 0))
            // 少しずつ遅れて動く。波のように見せる
            let phase = (CGFloat(frame) / CGFloat(frames) + CGFloat(index) * 0.083).truncatingRemainder(dividingBy: 1)
            let depth = (1 - cos(phase * 2 * .pi)) / 2
            let joints = sleeping ? lie : stand.mixed(with: squat, depth)
            let fill = palette[index % palette.count]
            func p(_ point: CGPoint) -> CGPoint { CGPoint(x: ankle.x + point.x * k * (sleeping ? 0.8 : 1), y: ankle.y + point.y * k) }
            for (stroke, lineWidth) in [(ink, 15 * k), (fill, 9 * k)] {
                context.setStrokeColor(stroke)
                context.setLineWidth(lineWidth)
                for points in [joints.legs, joints.arm] {
                    context.move(to: p(points[0]))
                    points.dropFirst().forEach { context.addLine(to: p($0)) }
                }
                context.strokePath()
            }
            let head = p(joints.head)
            for (paint, radius) in [(ink, 12 * k), (fill, 8.5 * k)] {
                context.setFillColor(paint)
                context.fillEllipse(in: CGRect(x: head.x - radius, y: head.y - radius, width: radius * 2, height: radius * 2))
            }
            index += 1
        }
    }
    let image = NSBitmapImageRep(cgImage: context.makeImage()!)
    try! image.representation(using: .png, properties: [:])!
        .write(to: out.appending(path: String(format: "%03d.png", frame)))
}
