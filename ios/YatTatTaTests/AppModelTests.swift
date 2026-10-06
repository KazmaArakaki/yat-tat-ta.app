import Foundation
import SwiftData
import Testing
@testable import YatTatTa

@MainActor struct AppModelTests {
    private let container = try! ModelContainer(
        for: SquatRecord.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    private let defaults: UserDefaults = {
        let name = "AppModelTests-\(UUID())"
        return UserDefaults(suiteName: name)!
    }()

    private func makeModel(now: Date = .now) -> AppModel {
        let model = AppModel(context: container.mainContext, defaults: defaults, now: { now })
        // フィーバーのくじは外れに固定する。当てたいテストだけ差し替える
        model.draw = { 1 }
        return model
    }

    private func records() -> [SquatRecord] {
        (try? container.mainContext.fetch(FetchDescriptor<SquatRecord>())) ?? []
    }

    @Test func 叩き切ると記録が1件できてフィナーレが出る() {
        let model = makeModel()
        model.targetReps = 5
        var taps: [MashSession.Tap] = []
        for i in 0..<5 { taps += [model.tap(at: Double(i) * 0.2)].compactMap { $0 } }

        #expect(taps.map(\.level) == [1, 3, 4, 6, 7])
        #expect(taps.last?.isFinal == true)
        #expect(records().map(\.reps) == [5])
        #expect(model.finale?.completed == true)
        #expect(model.finale?.streakExtended == 1)
        #expect(model.ledger.dopaTotal == 5)
        #expect(model.ledger.streak.doneToday)
        #expect(model.remaining == 5)
        #expect(model.showsReminderAsk)
    }

    @Test func 叩き切った直後は叩いても数えない() {
        let model = makeModel()
        model.targetReps = 5
        for i in 0..<5 { _ = model.tap(at: Double(i) * 0.2) }
        #expect(model.tap(at: 1.0) == nil)
        #expect(model.tap(at: 0.8 + MashSession.lockAfterFinale) != nil)
    }

    @Test func 途中で離れると叩いたところまでで1件() {
        let model = makeModel()
        for i in 0..<7 { _ = model.tap(at: Double(i) * 0.2) }
        #expect(model.dopaTotal == 7)
        #expect(records().isEmpty)

        model.sceneDidLeave()
        #expect(records().map(\.reps) == [7])
        #expect(model.finale?.completed == false)
        #expect(model.remaining == 20)
        #expect(model.ledger.streak.current == 1)
    }

    @Test func 叩いている途中で目標回数を変えてもその連打は変わらない() {
        let model = makeModel()
        _ = model.tap(at: 0)
        model.targetReps = 30
        #expect(model.remaining == 19)
        model.sceneDidLeave()
        #expect(model.remaining == 30)
    }

    @Test func DTの節目は連打の途中でもまたいだ1打で出る() {
        let model = makeModel()
        container.mainContext.insert(SquatRecord(startedAt: .now, day: RecordDay(.now), reps: 95))
        try! container.mainContext.save()
        let reloaded = makeModel()
        for i in 0..<5 { _ = reloaded.tap(at: Double(i) * 0.2) }
        // 100 は DT の節目でもあるので、札ではなく金のドパ突破で出す
        #expect(reloaded.toppa?.value == 100)
        #expect(reloaded.toppa?.gold == true)
        #expect(reloaded.passingMilestone == nil)
        _ = model
    }

    @Test func 百の倍数をまたぐとドパ突破が出る() {
        container.mainContext.insert(SquatRecord(startedAt: .now, day: RecordDay(.now), reps: 195))
        try! container.mainContext.save()
        let model = makeModel()
        for i in 0..<4 { _ = model.tap(at: Double(i) * 0.2) }
        #expect(model.toppa == nil)
        _ = model.tap(at: 1.0)
        #expect(model.toppa?.value == 200)
        #expect(model.toppa?.gold == false)
    }

    @Test func その日最初の叩き切りは今日もお疲れで確定の言葉は順に回る() {
        let model = makeModel()
        model.targetReps = 5
        for i in 0..<5 { _ = model.tap(at: Double(i) * 0.2) }
        #expect(model.finale?.negirai?.message == "今日もお疲れ！")
        #expect(model.finale?.kakutei == 0)
        for i in 0..<5 { _ = model.tap(at: 10 + Double(i) * 0.2) }
        #expect(model.finale?.kakutei == 1)
        #expect(model.finale?.negirai?.message != "今日もお疲れ！")
    }

    @Test func フィーバー中の1打はスクワットの残りを減らさずドパを足す() {
        let model = makeModel()
        model.targetReps = 5
        model.draw = { 0 }
        let first = model.tap(at: 0)
        #expect(first?.startedFever == true)
        #expect(model.fever != nil)
        model.draw = { 1 }
        let feverTap = model.tap(at: 0.2)
        #expect(feverTap?.isFever == true)
        #expect(feverTap?.dopa == 1)
        #expect(model.remaining == 4)
        #expect(model.dopaTotal == 2)
        // 最後の3秒はラッシュ。ドパは1のまま
        let rush = model.tap(at: 8.0)
        #expect(rush?.isRush == true)
        #expect(rush?.dopa == 1)
        #expect(model.fever?.gained == 2)
    }

    @Test func フィーバーのドパは記録の別の欄に残りDTに入る() {
        let model = makeModel()
        model.draw = { 0 }
        _ = model.tap(at: 0)
        model.draw = { 1 }
        for i in 1...3 { _ = model.tap(at: Double(i) * 0.2) }
        model.sceneDidLeave()
        let saved = records()
        #expect(saved.map(\.reps) == [1])
        #expect(saved.map(\.bonusDopa) == [3])
        #expect(model.ledger.dopaTotal == 4)
        #expect(model.ledger.streak.current == 1)
    }
}
