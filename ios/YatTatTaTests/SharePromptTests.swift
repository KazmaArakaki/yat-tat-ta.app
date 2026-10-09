import Foundation
import Testing
@testable import YatTatTa

/// 共有を促すカード。今日の記録があって、今日まだ共有していないときだけ出す
@MainActor struct SharePromptTests {
    private let store = MemoryRecordStore()
    private let defaults: UserDefaults = {
        let name = "SharePromptTests-\(UUID())"
        let d = UserDefaults(suiteName: name)!
        // 初めて叩き切ったときの通知の問いかけを、先に済ませておく
        d.set(true, forKey: SettingKey.reminderAsked)
        return d
    }()

    private func makeModel() -> AppModel {
        let model = AppModel(store: store, defaults: defaults)
        model.draw = { 1 }
        model.wake()
        model.targetReps = 5
        return model
    }

    /// 叩き切って、演出を飛ばすところまで
    private func mash(_ model: AppModel) {
        for i in 0..<5 { _ = model.tap(at: Double(i) * 0.2) }
        model.skipFinale()
    }

    @Test func 叩き切った演出が終わると出る() {
        let model = makeModel()
        mash(model)
        #expect(model.showsSharePrompt)
    }

    @Test func 今日の記録がなければ出ない() {
        let model = makeModel()
        model.offerShareIfNeeded()
        #expect(!model.showsSharePrompt)
    }

    @Test func 共有した日はもう出ない() {
        let model = makeModel()
        mash(model)
        model.markShared()
        #expect(!model.showsSharePrompt)
        mash(model)
        #expect(!model.showsSharePrompt)
        model.offerShareIfNeeded()
        #expect(!model.showsSharePrompt)
    }

    @Test func 今日はしないを押した日はもう出ない() {
        let model = makeModel()
        mash(model)
        model.declineShare()
        mash(model)
        #expect(!model.showsSharePrompt)
    }

    @Test func 閉じただけならアプリを開いたときにまた出る() {
        let model = makeModel()
        mash(model)
        model.showsSharePrompt = false
        model.sceneDidBecomeActive()
        // その日の最初に開いたときは、スプラッシュが消えてから
        if model.splash != nil { model.finishSplash() }
        #expect(model.showsSharePrompt)
    }

    @Test func 練習の演出のあとには出ない() {
        let model = AppModel(store: store, defaults: defaults)
        model.draw = { 1 }
        model.startTutorial()
        model.wake()
        for i in 0..<TutorialStep.practiceReps { _ = model.tap(at: Double(i) * 0.2) }
        model.skipFinale()
        #expect(!model.showsSharePrompt)
    }
}
