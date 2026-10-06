import Foundation
import Observation
import SwiftData

/// 画面が読む状態と、叩いたときの処理
///
/// 起動時に記録を全部読み、Ledger で計算する。叩いている間は画面の中の数を1ずつ足すだけで、
/// 記録を閉じたときに1件保存し、計算し直す。
@Observable final class AppModel {
    private(set) var ledger: Ledger
    private(set) var session: MashSession
    /// いま出しているフィナーレ。出し終えたら nil
    private(set) var finale: FinaleEvent?
    /// 連打の途中でまたいだ節目の札。少しだけ出して消す
    private(set) var passingMilestone: PassingMilestone?
    /// 途切れたときのカード
    var breakNotice: BreakNotice?
    /// 休み券を使ったときの帯
    var restPassNotice: RestPassNotice?
    /// 今日まだ通知の問いかけ
    var showsReminderAsk = false
    /// ドパドパの段階。画面全体の地を変える
    private(set) var hypeStage = HypeStage.normal
    /// 叩くたびに1増える。PUSH で画面を膨らませる合図
    private(set) var tapTick = 0
    /// ドパ突破（DT が100の倍数をまたいだ1打）
    private(set) var toppa: ToppaEvent?
    /// 段階に入った1打で、画面いっぱいに叩きつける文字
    private(set) var stageBanner: StageBanner?
    /// フィーバータイム中なら、その状態
    private(set) var fever: FeverState?
    /// フィーバーが終わったときに出す、取ったドパの合計
    private(set) var feverResult: FeverResult?
    /// フィーバーのくじ。0以上1未満の数を返す。テストでは決まった数に差し替える
    @ObservationIgnored var draw: () -> Double = { Double.random(in: 0..<1) }
    #if DEBUG
    /// 見本で、確定を飛ばしてねぎらいから出す
    @ObservationIgnored var demoSkipToNegirai = false
    /// 計測モードでは、今日まだ通知の予約に触れない。仮の記録で予約し直さないように
    @ObservationIgnored var remindersPaused = false
    #endif
    /// 最後の1打で節目に届くと分かった連打。PUSH に入った瞬間から立てる（虹の先バレ）
    private(set) var rainbow = false
    /// 今日（記録日）の記録。新しい順。今日の記録のシートに並べ、そこから消せる
    private(set) var todayRecords: [SquatRecord] = []

    @ObservationIgnored let feel = FeelEngine()
    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let reminder = ReminderScheduler()
    @ObservationIgnored private var daily: Ledger.DailyReps = [:]
    @ObservationIgnored private var idleTask: Task<Void, Never>?
    @ObservationIgnored private var finaleTask: Task<Void, Never>?
    @ObservationIgnored private var passingTask: Task<Void, Never>?
    @ObservationIgnored private var toppaTask: Task<Void, Never>?
    @ObservationIgnored private var bannerTask: Task<Void, Never>?
    @ObservationIgnored private var feverTask: Task<Void, Never>?
    @ObservationIgnored private var feverResultTask: Task<Void, Never>?
    /// いまのフィーバーが始まったときの、この連打のフィーバーのドパ
    @ObservationIgnored private var feverBaseline = 0
    @ObservationIgnored private let now: () -> Date

    init(context: ModelContext, defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init) {
        self.context = context
        self.defaults = defaults
        self.now = now
        defaults.register(defaults: [
            SettingKey.targetReps: TargetReps.default,
            SettingKey.reminderMinutes: ReminderTime.defaultMinutes,
        ])
        session = MashSession(target: defaults.integer(forKey: SettingKey.targetReps))
        ledger = Ledger(daily: [:], today: RecordDay(now()))
        loadRecords()
    }

    // MARK: - 画面に出す数

    var targetReps: Int {
        get { access(keyPath: \.targetReps); return defaults.integer(forKey: SettingKey.targetReps) }
        set {
            withMutation(keyPath: \.targetReps) { defaults.set(newValue, forKey: SettingKey.targetReps) }
            rescheduleReminder()
        }
    }

    /// ボタンに出す数。叩いていなければ目標回数
    var remaining: Int { session.isOpen ? session.remaining : targetReps }
    /// この連打で入ったドパ（スクワットとフィーバー）
    var converted: Int { session.dopa }
    var dopaTotal: Int { ledger.dopaTotal + session.dopa }
    var dopaPerWeek: Int { ledger.dopaPerWeek + session.dopa }

    // MARK: - 叩く

    /// 1打。数えない間は nil
    func tap(at time: TimeInterval) -> MashSession.Tap? {
        let date = now()
        if !session.isOpen { refreshIfDayChanged(date) }
        let totalBefore = dopaTotal
        let weekBefore = dopaPerWeek
        let wasOpen = session.isOpen
        guard let tap = session.tap(at: time, date: date, target: targetReps, draw: draw) else { return nil }
        if !wasOpen { feel.playBGM(.bgmMash) }

        let crossed = Milestone.dopaTotal(from: totalBefore, to: dopaTotal)
            + [Milestone.bestWindow(best: ledger.bestWindow, from: weekBefore, to: dopaPerWeek)].compactMap { $0 }
        session.milestones += crossed
        tapTick += 1

        if tap.isFever {
            fever?.gained = session.feverDopa - feverBaseline
            if tap.isRush && fever?.rush == false { feel.play(.voiceRush) }
            fever?.rush = tap.isRush
            feel.feverTap(rush: tap.isRush)
        } else {
            hypeStage = tap.isFinal ? .normal : tap.stage
            if tap.combo >= 10 && tap.combo % 10 == 0 { feel.play(.voiceCombo) }
            // スクワット隊が1人増える
            if tap.index % SquatStageUIView.recruitEvery == 0 && !tap.isFinal
                && 1 + tap.index / SquatStageUIView.recruitEvery <= SquatStageUIView.maxMembers { feel.recruit() }
            if tap.stage == .push && tap.enteredStage { rainbow = finalTapReachesMilestone() }
            feel.tap(level: tap.level, heavy: tap.stage >= .hot)
            if tap.enteredStage && !tap.isFinal {
                feel.enter(tap.stage)
                showBanner(tap.stage)
            }
        }

        // ドパ突破。フィーバーのドパでまたいでも出す
        if dopaTotal / 100 > totalBefore / 100 {
            let gold = crossed.contains { if case .dopaTotal = $0 { true } else { false } }
            showToppa(ToppaEvent(value: dopaTotal / 100 * 100, gold: gold))
        }

        if tap.startedFever {
            startFever()
        } else if tap.isFinal {
            close(completed: true)
        } else {
            // 100の倍数でもある DT の節目は、金のドパ突破で出すので札を重ねない
            if let first = crossed.first(where: { if case .dopaTotal = $0 { false } else { true } }) {
                feel.milestone()
                showPassing(first)
            }
            if !tap.isFever { scheduleIdleClose() }
        }
        return tap
    }

    // MARK: - フィーバータイム

    private func startFever() {
        idleTask?.cancel()
        feverBaseline = session.feverDopa
        fever = FeverState(endsAt: now().addingTimeInterval(MashSession.feverDuration))
        hypeStage = .push
        feel.feverStart()
        feverTask?.cancel()
        feverTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(MashSession.feverDuration))
            guard !Task.isCancelled else { return }
            self?.endFever()
        }
    }

    private func endFever() {
        guard let state = fever else { return }
        session.endFever(at: ProcessInfo.processInfo.systemUptime)
        fever = nil
        feel.feverEnd()
        feverResult = FeverResult(gained: state.gained)
        feverResultTask?.cancel()
        feverResultTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            self?.feverResult = nil
        }
        if session.remaining <= 0 {
            close(completed: true)
        } else {
            hypeStage = MashSession.stage(index: session.converted, target: session.target)
            feel.playBGM(hypeStage >= .hot ? .bgmHot : .bgmMash)
            scheduleIdleClose()
        }
    }

    /// この連打を叩き切ったとき、最後の1打で節目に届くか。くじではなく、記録から計算して分かる
    private func finalTapReachesMilestone() -> Bool {
        let rest = session.remaining
        if !Milestone.dopaTotal(from: dopaTotal, to: dopaTotal + rest).isEmpty { return true }
        if Milestone.bestWindow(best: ledger.bestWindow, from: dopaPerWeek, to: dopaPerWeek + rest) != nil { return true }
        let streak = ledger.streak
        return !streak.doneToday && Milestone.streak(reaching: streak.nextCount) != nil
    }

    /// アプリを離れたとき。叩いたところまでで1件にする
    func sceneDidLeave() {
        if session.isOpen { close(completed: false) }
    }

    func sceneDidBecomeActive() {
        refreshIfDayChanged(now())
        rescheduleReminder()
    }

    private func scheduleIdleClose() {
        idleTask?.cancel()
        idleTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(MashSession.idleTimeout))
            guard !Task.isCancelled else { return }
            self?.close(completed: false)
        }
    }

    private func close(completed: Bool) {
        idleTask?.cancel()
        let milestonesSoFar = session.milestones
        rainbow = false
        hypeStage = .normal
        feverTask?.cancel()
        fever = nil
        feel.stopBGM()
        guard let closed = session.close() else { return }

        let wasDoneToday = ledger.streak.doneToday
        let day = RecordDay(closed.startedAt)
        context.insert(SquatRecord(startedAt: closed.startedAt, day: day, reps: closed.reps, bonusDopa: closed.bonusDopa))
        do {
            try context.save()
        } catch {
            print("SwiftData: \(error)")
        }
        daily[day, default: 0] += closed.reps + closed.bonusDopa
        // session は作り直さない。叩き切ったあとの「数えない間」を残すため
        ledger = Ledger(daily: daily, today: RecordDay(now()))
        refreshTodayRecords()

        // その日最初の記録が閉じたとき、連続記録が伸びる
        let extended = !wasDoneToday && ledger.streak.doneToday
        var milestones = milestonesSoFar
        if extended, let m = Milestone.streak(reaching: ledger.streak.current) {
            milestones.insert(m, at: 0)
        }
        let kakutei = completed ? nextCount(SettingKey.kakuteiCount) : 0
        let negirai = completed ? chooseNegirai(extended: extended, milestones: milestones) : nil
        let timing = feel.finaleTiming(kakutei: kakutei, negirai: negirai?.voice ?? .voiceNegirai3)
        let event = FinaleEvent(completed: completed, reps: closed.reps + closed.bonusDopa, streakExtended: extended ? ledger.streak.current : nil,
                                milestones: milestones, kakutei: kakutei, negirai: negirai,
                                kakuteiDuration: timing.kakutei, negiraiDuration: timing.negirai)
        // ドパ突破やフィーバーの結果を出している途中なら、それを見せてから出す
        let delay = toppa != nil || feverResult != nil ? 1.0 : 0
        if completed, let negirai {
            feel.finale(kakutei: kakutei, negirai: negirai.voice, milestones: milestones, timing: timing, after: delay)
        } else if !milestones.isEmpty {
            feel.milestone()
        }
        if completed || extended || !milestones.isEmpty { show(event, after: delay) }

        if completed && !defaults.bool(forKey: SettingKey.reminderAsked) {
            defaults.set(true, forKey: SettingKey.reminderAsked)
            showsReminderAsk = true
        }
        rescheduleReminder()
    }

    private func show(_ event: FinaleEvent, after delay: TimeInterval = 0) {
        finaleTask?.cancel()
        if delay == 0 { finale = event }
        finaleTask = Task { [weak self] in
            if delay > 0 {
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { return }
                self?.finale = event
            }
            try? await Task.sleep(for: .seconds(event.duration))
            guard !Task.isCancelled else { return }
            self?.finale = nil
        }
    }

    /// 叩き切って1.2秒を過ぎたら、触って確定とねぎらいを飛ばせる
    func skipFinale() {
        guard finale != nil else { return }
        finaleTask?.cancel()
        finale = nil
    }

    private func showToppa(_ event: ToppaEvent) {
        toppa = event
        feel.toppa(gold: event.gold)
        toppaTask?.cancel()
        toppaTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(ToppaEvent.duration))
            guard !Task.isCancelled else { return }
            self?.toppa = nil
        }
    }

    private func showBanner(_ stage: HypeStage) {
        stageBanner = StageBanner(stage: stage)
        bannerTask?.cancel()
        bannerTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(StageBanner.duration))
            guard !Task.isCancelled else { return }
            self?.stageBanner = nil
        }
    }

    /// ねぎらいの言葉。上から順に、当てはまった最初の1つ
    private func chooseNegirai(extended: Bool, milestones: [Milestone]) -> Negirai {
        if let days = milestones.lazy.compactMap({ if case .streak(let n) = $0 { n } else { nil } }).first {
            return Negirai(headline: String(localized: "\(days)日連続！"), message: String(localized: "あんたはえらい！"),
                           voice: .voiceNegirai3)
        }
        if extended {
            return Negirai(headline: nil, message: String(localized: "今日もお疲れ！"), voice: .voiceNegirai1)
        }
        let hour = Calendar.current.component(.hour, from: now())
        if hour >= 21 || hour < RecordDay.boundaryHour {
            return Negirai(headline: nil, message: String(localized: "夜食のあとに、えらすぎる！"), voice: .voiceNegirai2)
        }
        let rotation: [(String, Sound)] = [
            (String(localized: "あんたはえらい！"), .voiceNegirai3),
            (String(localized: "よっ、太もも番長！"), .voiceNegirai4),
            (String(localized: "限界突破！"), .voiceNegirai5),
        ]
        let pick = rotation[nextCount(SettingKey.negiraiCount) % rotation.count]
        return Negirai(headline: nil, message: pick.0, voice: pick.1)
    }

    /// 言葉を順に回すための数。くじではなく、出した回数で決める
    private func nextCount(_ key: String) -> Int {
        let n = defaults.integer(forKey: key)
        defaults.set(n + 1, forKey: key)
        return n
    }

    private func showPassing(_ milestone: Milestone) {
        passingMilestone = PassingMilestone(milestone: milestone)
        passingTask?.cancel()
        passingTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            self?.passingMilestone = nil
        }
    }

    #if DEBUG
    func setDemoStage(_ stage: HypeStage) { hypeStage = stage }
    func setDemoToppa(_ event: ToppaEvent) { showToppa(event) }
    func setDemoBanner(_ stage: HypeStage) {
        hypeStage = stage
        showBanner(stage)
    }
    func setDemoFever() {
        feel.playBGM(.bgmMash)
        startFever()
    }
    func setDemoFinale(_ event: FinaleEvent, skipToNegirai: Bool) {
        demoSkipToNegirai = skipToNegirai
        let voice = event.negirai?.voice ?? .voiceNegirai3
        let timing = feel.finaleTiming(kakutei: event.kakutei, negirai: voice)
        var event = event
        event.kakuteiDuration = timing.kakutei
        event.negiraiDuration = timing.negirai
        feel.finale(kakutei: event.kakutei, negirai: voice, milestones: event.milestones, timing: timing, after: 0)
        finale = event
    }

    /// 計測モードの「もう1回」。記録を仮の記録に入れ替えて、読み直す
    func resetForPerf(_ records: [SquatRecord]) {
        if session.isOpen { _ = session.close() }
        idleTask?.cancel()
        finaleTask?.cancel()
        finale = nil
        for record in (try? context.fetch(FetchDescriptor<SquatRecord>())) ?? [] { context.delete(record) }
        records.forEach(context.insert)
        try? context.save()
        loadRecords()
    }
    #endif

    // MARK: - 記録を読む

    private func loadRecords() {
        let records = (try? context.fetch(FetchDescriptor<SquatRecord>())) ?? []
        daily = [:]
        for r in records { daily[r.recordDay, default: 0] += r.dopa }
        ledger = Ledger(daily: daily, today: RecordDay(now()))
        refreshTodayRecords()
        updateNotices()
    }

    private func refreshTodayRecords() {
        let today = ledger.today.value
        let descriptor = FetchDescriptor<SquatRecord>(
            predicate: #Predicate { $0.day == today },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        todayRecords = (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - 今日の記録

    /// 今日の記録を1件消す。昨日より前の記録と、叩いている最中は消さない
    ///
    /// 連続記録、休み券、DT、DPW は保存していないので、記録を読み直せば揃う。
    /// 出した節目の札は取り消さない。数が戻るので、次にまたいだときにもう一度出る。
    func delete(_ record: SquatRecord) {
        guard !session.isOpen, record.day == ledger.today.value else { return }
        context.delete(record)
        do {
            try context.save()
        } catch {
            print("SwiftData: \(error)")
        }
        loadRecords()
        rescheduleReminder()
    }

    /// 午前4時をまたいだら計算し直す。DPW から7日前の分が抜け、連続記録や休み券が動く
    private func refreshIfDayChanged(_ date: Date) {
        guard RecordDay(date) != ledger.today else { return }
        ledger = Ledger(daily: daily, today: RecordDay(date))
        refreshTodayRecords()
        updateNotices()
    }

    /// 途切れたときのカードと休み券の帯。どちらも1度だけ出す
    private func updateNotices() {
        let streak = ledger.streak
        if let b = streak.lastBreak, b.day.value > defaults.integer(forKey: SettingKey.shownBreakDay) {
            defaults.set(b.day.value, forKey: SettingKey.shownBreakDay)
            breakNotice = BreakNotice(length: b.length, best: streak.best, dopaTotal: ledger.dopaTotal)
        }
        let shown = defaults.integer(forKey: SettingKey.shownRestPassDay)
        let newUses = streak.restPassDays.filter { $0.value > shown }
        if let last = newUses.last {
            defaults.set(last.value, forKey: SettingKey.shownRestPassDay)
            // 途切れたあとの古い休み券は、帯ではなくカードで伝わる
            if streak.lastBreak.map({ $0.day < last }) ?? true {
                restPassNotice = RestPassNotice(used: newUses.count, streak: streak.current)
            }
        }
    }

    // MARK: - 今日まだ通知

    var reminderEnabled: Bool {
        get { access(keyPath: \.reminderEnabled); return defaults.bool(forKey: SettingKey.reminderEnabled) }
        set {
            withMutation(keyPath: \.reminderEnabled) { defaults.set(newValue, forKey: SettingKey.reminderEnabled) }
            rescheduleReminder()
        }
    }

    /// 0時からの分
    var reminderMinutes: Int {
        get { access(keyPath: \.reminderMinutes); return defaults.integer(forKey: SettingKey.reminderMinutes) }
        set {
            withMutation(keyPath: \.reminderMinutes) { defaults.set(newValue, forKey: SettingKey.reminderMinutes) }
            rescheduleReminder()
        }
    }

    /// 問いかけや設定で「知らせて」を選んだとき。許されなければ OFF のまま
    func enableReminder() async {
        let granted = await reminder.requestAuthorization()
        reminderEnabled = granted
    }

    func reminderDenied() async -> Bool {
        await reminder.isDenied()
    }

    private func rescheduleReminder() {
        #if DEBUG
        if remindersPaused { return }
        #endif
        reminder.reschedule(enabled: reminderEnabled, minutes: reminderMinutes, ledger: ledger,
                            target: targetReps, now: now())
    }
}

/// 記録が閉じたときに出す演出
struct FinaleEvent: Equatable, Identifiable {
    let id = UUID()
    /// 叩き切ったか。途中で閉じたときはフィナーレの文字を出さない
    let completed: Bool
    /// この記録で入ったドパ（スクワットとフィーバー）
    let reps: Int
    /// その日最初の記録で連続記録が伸びたら、伸びたあとの日数
    let streakExtended: Int?
    let milestones: [Milestone]

    /// 確定の言葉の番号（0〜4）。叩き切ったときだけ使う
    let kakutei: Int
    /// ねぎらい。叩き切ったときだけ
    let negirai: Negirai?

    /// 確定を見せる長さと、ねぎらいを見せる長さ。声の長さから決める（FeelEngine.finaleTiming）
    var kakuteiDuration: TimeInterval = 1.4
    var negiraiDuration: TimeInterval = 1.8
    /// 叩き切ってから、触って飛ばせるようになるまで
    static let skippableAfter: TimeInterval = 1.2

    static let kakuteiWords: [(String, String)] = [
        (String(localized: "筋肉"), String(localized: "確定")),
        (String(localized: "太もも"), String(localized: "確定")),
        (String(localized: "根性"), String(localized: "確定")),
        (String(localized: "継続"), String(localized: "確定")),
        (String(localized: "明日も"), String(localized: "確定")),
    ]

    /// 札が多いほど長く出す
    var duration: TimeInterval {
        (completed ? kakuteiDuration + negiraiDuration : 1.2) + 0.6 * Double(milestones.count)
    }
}

/// ねぎらいの言葉と声
struct Negirai: Equatable {
    /// 「30日連続！」のような前置き
    let headline: String?
    let message: String
    let voice: Sound
}

/// ドパ突破
struct ToppaEvent: Equatable, Identifiable {
    let id = UUID()
    /// またいだ100の倍数
    let value: Int
    /// DT の節目（1,000、1万、10万）なら金
    let gold: Bool

    static let duration: TimeInterval = 1.6
}

/// 段階に入った1打で叩きつける文字
struct StageBanner: Equatable, Identifiable {
    let id = UUID()
    let stage: HypeStage

    static let duration: TimeInterval = 0.9
}

/// フィーバータイム中の状態
struct FeverState: Equatable {
    let endsAt: Date
    /// このフィーバーで取ったドパ
    var gained = 0
    /// 最後の2秒（ラッシュ）に入ったか
    var rush = false
}

/// フィーバーが終わったときの結果
struct FeverResult: Equatable, Identifiable {
    let id = UUID()
    let gained: Int
}

struct PassingMilestone: Equatable, Identifiable {
    let id = UUID()
    let milestone: Milestone
}

struct BreakNotice: Equatable {
    let length: Int
    let best: Int
    let dopaTotal: Int
}

struct RestPassNotice: Equatable {
    let used: Int
    let streak: Int
}
