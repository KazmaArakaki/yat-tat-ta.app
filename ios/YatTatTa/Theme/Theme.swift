import SwiftUI
import UIKit

/// 色と文字。docs/ui/principles.html の決まり事を写したもの
///
/// 色は意味ごとに1つ。ドパは dopa、押せるものは gold、休み券は signal。
/// 暗い配色で入れ替えるのは地と文字と枠だけ。
enum Palette {
    static let paper = dynamic(light: 0xFBF6EE, dark: 0x16120F)
    static let ink = dynamic(light: 0x1C1916, dark: 0xF5EEE3)
    static let card = dynamic(light: 0xFFFFFF, dark: 0x231D18)
    static let mute = dynamic(light: 0x6E655C, dark: 0xA89C8E)
    static let rule = dynamic(light: 0xE7DDCC, dark: 0x3A312A)
    static let dopaSoft = dynamic(light: 0xFFE6F0, dark: 0x3A1726)
    static let dopa = UIColor(hex: 0xE5337A)
    static let gold = UIColor(hex: 0xE9A800)
    static let signal = UIColor(hex: 0x2F79F7)
    /// 金色のボタンの文字。暗い配色でも ink の明るい色のまま
    static let onGold = UIColor(hex: 0x1C1916)

    private static func dynamic(light: UInt32, dark: UInt32) -> UIColor {
        UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) }
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

extension Color {
    static let paper = Color(Palette.paper)
    static let ink = Color(Palette.ink)
    static let card = Color(Palette.card)
    static let mute = Color(Palette.mute)
    static let rule = Color(Palette.rule)
    static let dopa = Color(Palette.dopa)
    static let dopaSoft = Color(Palette.dopaSoft)
    static let gold = Color(Palette.gold)
    static let signal = Color(Palette.signal)
    static let onGold = Color(Palette.onGold)
}

extension Font {
    /// 数字。SF Pro Rounded の Heavy、等幅の数字
    static func number(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .rounded).monospacedDigit()
    }

    /// 日本語の見出しと短い文。Bold か Black だけを使う
    static func label(_ size: CGFloat, black: Bool = false) -> Font {
        .system(size: size, weight: black ? .black : .bold)
    }
}

extension UIFont {
    static func number(_ size: CGFloat) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: .heavy)
        let rounded = base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor
        let mono = rounded.addingAttributes([.featureSettings: [[
            UIFontDescriptor.FeatureKey.type: kNumberSpacingType,
            UIFontDescriptor.FeatureKey.selector: kMonospacedNumbersSelector,
        ]]])
        return UIFont(descriptor: mono, size: size)
    }
}

/// 太い枠と、ぼかさずにずらした影。押すと沈むおもちゃの見た目
struct ToyCard: ViewModifier {
    var radius: CGFloat = 16
    var shadow: CGFloat = 4

    func body(content: Content) -> some View {
        content
            .background(Color.card, in: .rect(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(Color.ink, lineWidth: 2))
            .background(Color.ink, in: .rect(cornerRadius: radius).offset(x: shadow, y: shadow))
    }
}

extension View {
    func toyCard(radius: CGFloat = 16, shadow: CGFloat = 4) -> some View {
        modifier(ToyCard(radius: radius, shadow: shadow))
    }
}
