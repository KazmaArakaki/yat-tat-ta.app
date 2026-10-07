// App Store のスクリーンショットに見出しの帯を付ける
//
// screenshots.sh が撮った画像（raw/{言語}/{大きさ}/{番号}-{場面}.png）の上に見出しを描き、
// 画面を少し縮めて置いたものを、出力先の同じ並びに書き出す。macOS の CoreGraphics だけで描く。
//
//     swift ios/Design/compose_screenshots.swift <raw の場所> <出力先>
//
// 見出しを変えたら、docs/devops/app-store#screenshots の表4も同じ変更で直す。
// 寸法は docs/sessions/20261007-1523-app-store-review/screenshots.html の表1。
import AppKit
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// 見出しの1行の部品。accent はドパの色にする語
struct Part {
    let text: String
    var accent = false
}

/// 場面ごとの見出し。2行まで。改行は "\n"
let captions: [String: [String: [Part]]] = [
    "squad": [
        "ja": [Part(text: "スクワット1回を、\n"), Part(text: "1打", accent: true), Part(text: "で。")],
        "en": [Part(text: "One "), Part(text: "tap", accent: true), Part(text: "\nfor every squat.")],
    ],
    "fever": [
        "ja": [Part(text: "ときどき、\n"), Part(text: "FEVER", accent: true), Part(text: "。")],
        "en": [Part(text: "Sometimes,\n"), Part(text: "FEVER!!", accent: true)],
    ],
    "kakutei": [
        "ja": [Part(text: "最後の1打で、\n"), Part(text: "筋肉確定", accent: true), Part(text: "。")],
        "en": [Part(text: "The last tap\n"), Part(text: "locks it in.", accent: true)],
    ],
    "home": [
        "ja": [Part(text: "続けた日と、\n"), Part(text: "今週のドパ", accent: true), Part(text: "。")],
        "en": [Part(text: "Your streak,\nyour "), Part(text: "best week.", accent: true)],
    ],
    "history": [
        "ja": [Part(text: "いつ何回しゃがんだか、\n"), Part(text: "全部残る", accent: true), Part(text: "。")],
        "en": [Part(text: "Every set,\n"), Part(text: "on the record.", accent: true)],
    ],
    "splash": [
        "ja": [Part(text: "今日の席は、\n"), Part(text: "あなたの1回", accent: true), Part(text: "で埋まる。")],
        "en": [Part(text: "Today's seat is\n"), Part(text: "yours to fill.", accent: true)],
    ],
]

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

let paper = color(0xFBF6EE)
let rule = color(0xE7DDCC, alpha: 0.55)
let ink = color(0x1C1916)
let dopa = color(0xE5337A)

/// アプリの数字や札と同じ、システムの丸ゴシックの Heavy
///
/// 日本語の字はシステムに任せると細い字で代わりに描かれるので、ヒラギノ角ゴの W8 を代わりの書体に指定する。
func roundedHeavy(_ size: CGFloat) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: .heavy)
    let rounded = base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor
    let cascaded = rounded.addingAttributes([
        .cascadeList: [NSFontDescriptor(name: "HiraginoSans-W8", size: size)],
    ])
    return NSFont(descriptor: cascaded, size: size) ?? base
}

func caption(_ parts: [Part], size: CGFloat) -> NSAttributedString {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    paragraph.lineHeightMultiple = 1.08
    let text = NSMutableAttributedString()
    for part in parts {
        text.append(NSAttributedString(string: part.text, attributes: [
            .font: roundedHeavy(size),
            .foregroundColor: part.accent ? dopa : ink,
            .paragraphStyle: paragraph,
        ]))
    }
    return text
}

func loadImage(_ url: URL) -> CGImage? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
}

func writePNG(_ image: CGImage, to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw CocoaError(.fileWriteUnknown)
    }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else { throw CocoaError(.fileWriteUnknown) }
}

/// 撮った画面1枚を、同じ大きさの帯付きの画像にする
func compose(_ shot: CGImage, parts: [Part]) -> CGImage? {
    let w = CGFloat(shot.width), h = CGFloat(shot.height)
    // App Store は透明を受け付けないので、アルファなしで描く
    guard let ctx = CGContext(data: nil, width: shot.width, height: shot.height, bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpace(name: CGColorSpace.sRGB)!,
                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
    // 上を原点にして描く。文字と画像は描くときに向きを戻す
    ctx.translateBy(x: 0, y: h)
    ctx.scaleBy(x: 1, y: -1)

    // 紙の地と薄い点
    ctx.setFillColor(paper)
    ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
    ctx.setFillColor(rule)
    let pitch = w * 0.06, dot = w * 0.0022
    var y = pitch / 2
    while y < h {
        var x = pitch / 2
        while x < w {
            ctx.fillEllipse(in: CGRect(x: x - dot, y: y - dot, width: dot * 2, height: dot * 2))
            x += pitch
        }
        y += pitch
    }

    // 見出し。入りきらなければ縮める
    let box = CGRect(x: w * 0.08, y: h * 0.062, width: w * 0.84, height: h * 0.16)
    var size = w * 0.083
    var text = caption(parts, size: size)
    var framesetter = CTFramesetterCreateWithAttributedString(text)
    var fit = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRange(), nil,
                                                           CGSize(width: box.width, height: .greatestFiniteMagnitude), nil)
    while (fit.height > box.height || text.string.split(separator: "\n").contains { line in
        NSAttributedString(string: String(line), attributes: [.font: roundedHeavy(size)]).size().width > box.width
    }) && size > w * 0.04 {
        size *= 0.95
        text = caption(parts, size: size)
        framesetter = CTFramesetterCreateWithAttributedString(text)
        fit = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRange(), nil,
                                                           CGSize(width: box.width, height: .greatestFiniteMagnitude), nil)
    }
    let textRect = CGRect(x: box.minX, y: box.midY - fit.height / 2, width: box.width, height: ceil(fit.height) + 1)
    ctx.saveGState()
    ctx.translateBy(x: 0, y: textRect.maxY + textRect.minY)
    ctx.scaleBy(x: 1, y: -1)
    let frame = CTFramesetterCreateFrame(framesetter, CFRange(), CGPath(rect: textRect, transform: nil), nil)
    CTFrameDraw(frame, ctx)
    ctx.restoreGState()

    // 画面。幅の82%に縮め、下は枠の外へはみ出させる
    let screenW = w * 0.82
    let screen = CGRect(x: w * 0.09, y: h * 0.25, width: screenW, height: screenW * h / w)
    let radius = w * 0.075, line = w * 0.012, shadow = w * 0.025
    ctx.setFillColor(ink)
    ctx.addPath(CGPath(roundedRect: screen.offsetBy(dx: shadow, dy: shadow), cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.fillPath()
    let outline = CGPath(roundedRect: screen, cornerWidth: radius, cornerHeight: radius, transform: nil)
    ctx.saveGState()
    ctx.addPath(outline)
    ctx.clip()
    ctx.translateBy(x: 0, y: screen.maxY + screen.minY)
    ctx.scaleBy(x: 1, y: -1)
    ctx.interpolationQuality = .high
    ctx.draw(shot, in: screen)
    ctx.restoreGState()
    ctx.setStrokeColor(ink)
    ctx.setLineWidth(line)
    ctx.addPath(outline)
    ctx.strokePath()

    return ctx.makeImage()
}

let args = CommandLine.arguments
guard args.count == 3 else {
    print("使い方: swift compose_screenshots.swift <raw の場所> <出力先>")
    exit(2)
}
let rawRoot = URL(fileURLWithPath: args[1]), outRoot = URL(fileURLWithPath: args[2])
let files = FileManager.default.enumerator(at: rawRoot, includingPropertiesForKeys: nil)?
    .compactMap { $0 as? URL }.filter { $0.pathExtension == "png" }.sorted { $0.path < $1.path } ?? []
var failed = false
for url in files {
    // raw/{言語}/{大きさ}/{番号}-{場面}.png
    let parts = url.pathComponents.suffix(3)
    let lang = parts[parts.startIndex], name = url.deletingPathExtension().lastPathComponent
    let scene = String(name.drop { $0 != "-" }.dropFirst())
    guard let text = captions[scene]?[lang] else {
        print("見出しがない: \(scene) / \(lang)")
        failed = true
        continue
    }
    guard let shot = loadImage(url), let image = compose(shot, parts: text) else {
        print("描けなかった: \(url.path)")
        failed = true
        continue
    }
    let out = outRoot.appendingPathComponent(parts.joined(separator: "/"))
    try writePNG(image, to: out)
    print("書き出した: \(out.path)")
}
exit(failed ? 1 : 0)
