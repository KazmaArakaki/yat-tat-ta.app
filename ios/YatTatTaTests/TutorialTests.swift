import Foundation
import Testing
@testable import YatTatTa

/// チュートリアルと練習連打。練習が記録に漏れないことをいちばんに確かめる
@MainActor struct TutorialTests {
    private let store = MemoryRecordStore()
    private let defaults: UserDefaults = {
        let name = "TutorialTests-\(UUID())"
        return UserDefaults(suiteName: name)!
    }()

    private func makeModel() -> AppModel {
        let model = AppModel(store: store, defaults: defaults)
        // くじは当たりに固定する。練習では引かないことを確かめるため
        model.draw = { 0 }
        return model
    }

    private func records() -> [SquatRecord] {
        store.records
    }

    /// 起こして、練習を叩き切るところまで
    private func practice(_ model: AppModel) {
        model.wake()
        for i in 0..<TutorialStep.practiceReps { _ = model.tap(at: Double(i) * 0.2) }
    }

    @Test func 記録がない人にはスプラッシュのあとに出る() {
        let model = makeModel()
        model.finishSplash()
        #expect(model.tutorial == .wake)
    }

    @Test func 記録がある人には出ない() {
        store.add(SquatRecord(startedAt: .now, day: RecordDay(.now), reps: 20, bonusDopa: 0))
        let model = makeModel()
        model.finishSplash()
        #expect(model.tutorial == nil)
    }

    @Test func 起こすと練習連打へ進み残りは練習の回数() {
        let model = makeModel()
        model.startTutorial()
        #expect(model.tap(at: 0) == nil)
        model.wake()
        #expect(model.tutorial == .mash)
        #expect(model.remaining == TutorialStep.practiceReps)
    }

    @Test func 練習は記録を作らずドパの合計も動かさない() {
        let model = makeModel()
        model.targetReps = 30
        model.startTutorial()
        model.wake()
        _ = model.tap(at: 0)
        #expect(model.dopaTotal == 0)
        #expect(model.dopaPerWeek == 0)
        for i in 1..<TutorialStep.practiceReps { _ = model.tap(at: Double(i) * 0.2) }

        #expect(records().isEmpty)
        #expect(model.ledger.dopaTotal == 0)
        #expect(!model.ledger.streak.doneToday)
        #expect(model.finale?.practice == true)
        #expect(model.finale?.reps == TutorialStep.practiceReps)
        #expect(model.finale?.milestones.isEmpty == true)
        #expect(!model.showsReminderAsk)
        #expect(!model.squadAwake)
    }

    @Test func 練習ではフィーバーのくじを引かない() {
        let model = makeModel()
        model.startTutorial()
        model.wake()
        let tap = model.tap(at: 0)
        #expect(tap?.startedFever == false)
        #expect(model.fever == nil)
    }

    @Test func 練習のフィナーレが終わるといまのは練習へ() {
        let model = makeModel()
        model.startTutorial()
        practice(model)
        #expect(model.tutorial == .mash)
        model.skipFinale()
        #expect(model.tutorial == .after)
        #expect(model.remaining == model.targetReps)
    }

    @Test func 叩けば進む場面だけ進み最後は見せたことになる() {
        let model = makeModel()
        model.startTutorial()
        model.advanceTutorial()
        #expect(model.tutorial == .wake)
        practice(model)
        model.skipFinale()
        for expected in [TutorialStep.streak, .totals, .gear, .finish] {
            model.advanceTutorial()
            #expect(model.tutorial == expected)
        }
        model.advanceTutorial()
        #expect(model.tutorial == .finish)
        model.endTutorial()
        #expect(model.tutorial == nil)
        #expect(defaults.bool(forKey: SettingKey.tutorialShown))
        model.finishSplash()
        #expect(model.tutorial == nil)
    }

    @Test func 練習の途中でスキップすると練習を捨ててスクワットマンは寝る() {
        let model = makeModel()
        model.startTutorial()
        model.wake()
        _ = model.tap(at: 0)
        model.endTutorial()
        #expect(!model.session.isOpen)
        #expect(!model.squadAwake)
        #expect(records().isEmpty)
        #expect(model.finale == nil)
        #expect(defaults.bool(forKey: SettingKey.tutorialShown))
        // 本番は起こすところから
        #expect(model.tap(at: 5) == nil)
    }

    @Test func 練習の途中でアプリを離れると練習を捨てて場面はそのまま() {
        let model = makeModel()
        model.startTutorial()
        model.wake()
        _ = model.tap(at: 0)
        model.sceneDidLeave()
        #expect(!model.session.isOpen)
        #expect(records().isEmpty)
        #expect(model.tutorial == .mash)
        #expect(!defaults.bool(forKey: SettingKey.tutorialShown))
    }

    @Test func 見直しでは記録がある人も練習で記録が増えない() {
        store.add(SquatRecord(startedAt: .now, day: RecordDay(.now), reps: 20, bonusDopa: 0))
        let model = makeModel()
        model.startTutorial()
        practice(model)
        #expect(records().count == 1)
        #expect(model.dopaTotal == 20)
    }
}
