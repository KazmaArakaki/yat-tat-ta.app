import Foundation

/// チュートリアルの場面。はじめての幕のあと、約1分で使い方を指でやってもらう
///
/// 起こす、練習連打、いまのは練習、の3つは叩く場所を照らす。そのあと帯を照らし、今日の記録カードの見本を見せ、
/// カード、歯車を順に照らす。
/// まだ Apple でログインしていない人には、記録を残す場面で Apple でのログインを案内し、「はじめる」で終える。
/// 記録は作らない（docs/features/tutorial）。
enum TutorialStep: Int, CaseIterable {
    case wake, mash, after, streak, share, totals, gear, account, finish

    /// 練習連打の回数。目標回数によらない。10回で CHANCE、激熱、PUSH を全部通る
    static let practiceReps = 10

    /// 照らす場所。ないときは全体を暗くする
    var target: TutorialTarget? {
        switch self {
        case .wake, .mash, .after: .stage
        case .streak: .streak
        case .totals: .totals
        case .gear: .gear
        case .share, .account, .finish: nil
        }
    }

    /// どこかを叩くと次へ進む場面。起こすと練習連打は、やってもらうことが次へ進む合図
    var advancesByTap: Bool {
        switch self {
        case .wake, .mash, .account, .finish: false
        case .after, .streak, .share, .totals, .gear: true
        }
    }

    var next: TutorialStep? { TutorialStep(rawValue: rawValue + 1) }

    /// 進み具合の点に数える場面。記録を残すとおわりは数えない（記録を残すは、出さない人がいる）
    static let counted: [TutorialStep] = [.wake, .mash, .after, .streak, .share, .totals, .gear]
}

/// 照らす場所。HomeView が画面の上の位置を測って渡す
enum TutorialTarget: Hashable {
    case stage, streak, totals, gear
}
