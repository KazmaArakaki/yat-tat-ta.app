import SwiftUI

/// ホーム。上に連続記録、まん中に完了連打のボタン、下に DPW と DT
///
/// 画面はこの1枚だけ。フィナーレやカードは上に重ねて、用が済めば消す。
struct HomeView: View {
    let model: AppModel
    /// 設定シートのアカウントの欄に使う。計測モードと演出の見本では nil
    let account: Account?
    @State private var showsSettings = false
    @State private var showsToday = false
    /// 開いた時点の履歴。開くたびに記録を読み直す
    @State private var history: History?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var systemScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// PUSH のあいだ、叩くたびに画面をわずかに膨らませる
    @State private var swell = false
    /// 帯の日数の数字の位置。スプラッシュの数が飛ぶ先
    @State private var streakNumberFrame: CGRect?
    /// チュートリアルで照らす場所の位置（画面全体の座標）
    @State private var tutorialFrames: [TutorialTarget: CGRect] = [:]

    var body: some View {
        ZStack {
            StageBackdrop(stage: model.hypeStage, active: model.session.isOpen, tick: model.tapTick)

            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    StreakBar(streak: model.ledger.streak, todayCount: model.todayRecords.count,
                              openToday: { showsToday = true }, canOpenToday: !model.session.isOpen,
                              hidesNumber: model.splash != nil && !reduceMotion,
                              onNumberFrame: { streakNumberFrame = $0 })
                        .animation(.spring(duration: 0.5, bounce: 0.4), value: model.ledger.streak)
                        .measure(.streak, into: $tutorialFrames)
                    Button {
                        showsSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color.ink)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(Text("設定"))
                    .measure(.gear, into: $tutorialFrames)
                    .padding(.leading, 8)
                }
                // 上の帯と下のカードのあいだ、画面の幅いっぱいが叩く場所
                SquatStageView(model: model)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .measure(.stage, into: $tutorialFrames)
                    .padding(.vertical, 8)
                TotalsCards(dopaPerWeek: model.dopaPerWeek, previousWindow: model.ledger.previousWindow,
                            bestWindow: model.ledger.bestWindow, dopaTotal: model.dopaTotal,
                            openHistory: { history = model.history() }, canOpenHistory: !model.session.isOpen)
                    .measure(.totals, into: $tutorialFrames)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 16)
            // 激熱で地が暗転したら、帯とカードも暗い配色にして読めるようにする
            .environment(\.colorScheme, model.hypeStage >= .hot ? .dark : systemScheme)
            .scaleEffect(swell ? 1.025 : 1)

            tutorial

            overlays

            splash
        }
        .foregroundStyle(Color.ink)
        #if DEBUG
        .task {
            model.runDemoFromLaunchArguments()
            if model.demoOpensHistory { history = model.history() }
        }
        #endif
        .onChange(of: model.tapTick) {
            guard model.hypeStage == .push, !reduceMotion else { return }
            swell = true
            withAnimation(.easeOut(duration: 0.18)) { swell = false }
        }
        .sheet(isPresented: $showsSettings) {
            SettingsView(model: model, account: account)
        }
        .sheet(isPresented: $showsToday) {
            TodayRecordsView(model: model)
        }
        .sheet(isPresented: Binding(get: { history != nil }, set: { if !$0 { history = nil } })) {
            if let history { HistoryView(history: history) }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: model.sceneDidBecomeActive()
            case .inactive, .background: model.sceneDidLeave()
            @unknown default: break
            }
        }
    }

    /// チュートリアル。段階の文字やフィナーレより下に置き、練習のフィナーレの間は引っ込める
    @ViewBuilder private var tutorial: some View {
        if let step = model.tutorial, model.finale == nil {
            TutorialOverlay(step: step, frames: tutorialFrames, targetReps: model.targetReps,
                            firstTime: model.ledger.dopaTotal == 0,
                            advance: { withAnimation { model.advanceTutorial() } },
                            end: { withAnimation { model.endTutorial() } })
                .transition(.opacity)
        }
    }

    /// スプラッシュ。ほかの重ね物より上に置き、消えるまで叩いても数えない
    @ViewBuilder private var splash: some View {
        if let splash = model.splash {
            Group {
                switch splash.kind {
                case .regular:
                    SplashOverlay(splash: splash, target: streakNumberFrame,
                                  beats: { model.feel.beats($0) }, finish: { model.finishSplash() })
                case .intro:
                    IntroSplash(target: streakNumberFrame,
                                beats: { model.feel.beats($0) }, finish: { model.finishSplash() })
                }
            }
            .id(splash.id)
            // 引き継ぎで数が帯に着いたら、そのまま消す
            .transition(.identity)
        }
    }

    @ViewBuilder private var overlays: some View {
        if let banner = model.stageBanner {
            StageBannerOverlay(banner: banner)
                .id(banner.id)
                .transition(.opacity)
        }
        if let fever = model.fever {
            FeverOverlay(model: model, state: fever)
                .transition(.opacity)
        }
        if let toppa = model.toppa {
            ToppaOverlay(event: toppa)
                .id(toppa.id)
                .transition(.opacity)
        }
        if let result = model.feverResult {
            FeverResultOverlay(result: result)
                .id(result.id)
        }
        if let finale = model.finale {
            FinaleOverlay(event: finale, skip: { withAnimation { model.skipFinale() } }, startAtNegirai: demoNegirai)
                .id(finale.id)
                .transition(.opacity)
        } else if let passing = model.passingMilestone {
            MilestoneTag(milestone: passing.milestone)
                .id(passing.id)
                .transition(.scale.combined(with: .opacity))
                .allowsHitTesting(false)
        }

        // 休み券の帯、途切れたときのカード、通知の問いかけは、スプラッシュとチュートリアルが消えてから出す
        if model.splash == nil && model.tutorial == nil {
            notices
        }
    }

    @ViewBuilder private var notices: some View {
        if let notice = model.restPassNotice {
            VStack {
                RestPassBanner(notice: notice)
                Spacer()
            }
            .transition(.move(edge: .top).combined(with: .opacity))
            .task {
                try? await Task.sleep(for: .seconds(2))
                withAnimation { model.restPassNotice = nil }
            }
        }

        if let notice = model.breakNotice {
            scrim
            VStack {
                Spacer()
                StreakBreakCard(notice: notice) {
                    withAnimation { model.breakNotice = nil }
                }
            }
            .transition(.move(edge: .bottom))
        } else if model.showsReminderAsk && model.finale == nil {
            scrim
            VStack {
                Spacer()
                ReminderAskCard(minutes: model.reminderMinutes) { yes in
                    withAnimation { model.showsReminderAsk = false }
                    if yes { Task { await model.enableReminder() } }
                }
            }
            .transition(.move(edge: .bottom))
        }
    }

    private var demoNegirai: Bool {
        #if DEBUG
        model.demoSkipToNegirai
        #else
        false
        #endif
    }

    private var scrim: some View {
        Color.black.opacity(0.35).ignoresSafeArea().transition(.opacity)
    }
}

private extension View {
    /// チュートリアルで照らすために、画面全体の座標で位置を測る
    func measure(_ target: TutorialTarget, into frames: Binding<[TutorialTarget: CGRect]>) -> some View {
        onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frames.wrappedValue[target] = $0 }
    }
}
