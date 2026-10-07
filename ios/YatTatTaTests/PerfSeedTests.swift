import Foundation
import Testing
@testable import YatTatTa

@MainActor struct PerfSeedTests {
    private let store = MemoryRecordStore()
    private let now = Date(timeIntervalSince1970: 1_791_000_000)

    private func makeModel() -> AppModel {
        PerfSeed.records(today: RecordDay(now), now: now).forEach(store.add)
        let model = AppModel(store: store, defaults: PerfSeed.defaults(), now: { [now] in now })
        let draw = PerfSeed.FeverDraw()
        model.draw = { draw.next() }
        model.wake()
        return model
    }

    @Test func 仮の記録は29日連続でDT900とベスト240() {
        let model = makeModel()
        #expect(model.ledger.streak.current == 29)
        #expect(!model.ledger.streak.doneToday)
        #expect(model.ledger.dopaTotal == 900)
        #expect(model.ledger.dopaPerWeek == 141)
        #expect(model.ledger.bestWindow == 240)
        #expect(model.targetReps == 100)
        #expect(model.breakNotice == nil)
        #expect(model.restPassNotice == nil)
    }

    @Test func 最後の1打で節目が2つまたがりフィーバーが当たる() {
        let model = makeModel()
        var taps: [MashSession.Tap] = []
        for i in 0..<100 { taps += [model.tap(at: Double(i) * 0.1)].compactMap { $0 } }

        #expect(taps.count == 100)
        #expect(taps.dropLast().allSatisfy { !$0.startedFever })
        #expect(taps.last?.isFinal == true)
        #expect(taps.last?.startedFever == true)
        #expect(model.session.milestones == [.dopaTotal(1_000), .bestWindow(240)])
        #expect(model.toppa?.gold == true)
        #expect(model.fever != nil)
    }

    @Test func フィーバーのあとに閉じると連続30日を足して札が3枚() async throws {
        let model = makeModel()
        for i in 0..<100 { _ = model.tap(at: Double(i) * 0.1) }
        // フィーバーの5秒を待つ代わりに、フィーバー中に何打か叩いてから離れる
        for i in 0..<20 { _ = model.tap(at: 10 + Double(i) * 0.1) }
        model.sceneDidLeave()
        // ドパ突破を出している間は、フィナーレを1秒遅らせて出す
        try await Task.sleep(for: .seconds(1.2))

        #expect(model.ledger.streak.current == 30)
        #expect(model.finale?.milestones == [.streak(30), .dopaTotal(1_000), .bestWindow(240)])
        #expect(model.ledger.dopaTotal == 1_020)
    }

    @Test func くじはやり直すと100打目に戻る() {
        let draw = PerfSeed.FeverDraw()
        for _ in 0..<37 { _ = draw.next() }
        draw.reset()
        let hits = (1...200).filter { _ in draw.next() == 0 }
        #expect(hits.count == 2)
    }
}
