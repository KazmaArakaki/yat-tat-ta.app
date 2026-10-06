#if DEBUG
import SwiftUI

/// 計測の札。叩いている間は左上に小さく、フィナーレが消えたらまとめの札にする
///
/// 色は合格の線で塗る。緑は線の内側、黄は線の近く、赤は外側（docs/devops/perf-check）。
struct PerfHUD: View {
    let monitor: PerfMonitor
    let model: AppModel
    let restart: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let summary = monitor.summary {
                Color.black.opacity(0.35).ignoresSafeArea()
                SummaryCard(summary: summary, restart: restart)
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                LiveBadge(live: monitor.live, running: monitor.running, run: monitor.run, restart: restart)
                    .padding(.leading, 12)
                    .padding(.top, 4)
            }
        }
        .onChange(of: model.finale?.id) { old, new in
            if old != nil && new == nil { monitor.finish() }
        }
    }
}

private struct LiveBadge: View {
    let live: PerfMonitor.Live
    let running: Bool
    let run: Int
    let restart: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                if running {
                    row("fps", "\(live.fps)", PerfGrade.fps(live.fps), extra: live.minFps.map { ("最低", "\($0)", PerfGrade.fps($0)) })
                    row("≥50ms", "\(live.hitches)", PerfGrade.hitches(live.hitches))
                    row("発火", live.lastLatency.map(ms) ?? "-", live.lastLatency.map(PerfGrade.latency) ?? .plain,
                        extra: live.maxLatency.map { ("最大", ms($0), PerfGrade.latency($0)) })
                    row("切った声", "\(live.cuts)", PerfGrade.voiceCuts(live.cuts))
                    Text(verbatim: "打 \(live.taps)").foregroundStyle(.white.opacity(0.45))
                } else {
                    Text(verbatim: "PERF \(run)回目").foregroundStyle(.white.opacity(0.6))
                    Text(verbatim: "100打を叩き切る").foregroundStyle(.white)
                }
            }
            .allowsHitTesting(false)
            Button(action: restart) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 26, height: 26)
                    .background(.white.opacity(0.12), in: .circle)
            }
            .accessibilityLabel(Text(verbatim: "計測をやり直す"))
        }
        .font(.system(size: 10, design: .monospaced))
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.black.opacity(0.78), in: .rect(cornerRadius: 10))
    }

    private func row(_ label: String, _ value: String, _ grade: PerfGrade,
                     extra: (String, String, PerfGrade)? = nil) -> some View {
        HStack(spacing: 4) {
            Text(verbatim: label).foregroundStyle(.white.opacity(0.5))
            Text(verbatim: value).foregroundStyle(grade.color).bold()
            if let extra {
                Text(verbatim: extra.0).foregroundStyle(.white.opacity(0.5))
                Text(verbatim: extra.1).foregroundStyle(extra.2.color).bold()
            }
        }
    }
}

private struct SummaryCard: View {
    let summary: PerfMonitor.Summary
    let restart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(verbatim: "PERF / \(summary.run)回目").font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
            Text(verbatim: "打 \(summary.taps)").font(.system(size: 16, weight: .bold, design: .monospaced))
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                GridRow {
                    label("描画 最低")
                    value(summary.minFps.map { "\($0) fps" } ?? "-", summary.minFps.map(PerfGrade.fps) ?? .plain)
                }
                GridRow {
                    label("≥50ms")
                    value("\(summary.hitches) 回", PerfGrade.hitches(summary.hitches))
                }
                GridRow {
                    label("発火")
                    HStack(spacing: 4) {
                        Text(verbatim: "中央").foregroundStyle(.white.opacity(0.5))
                        value(ms(summary.median), PerfGrade.latency(summary.median))
                        Text(verbatim: "95%").foregroundStyle(.white.opacity(0.5))
                        value(ms(summary.p95), PerfGrade.latency(summary.p95))
                        Text(verbatim: "最大").foregroundStyle(.white.opacity(0.5))
                        value(ms(summary.max), PerfGrade.latency(summary.max))
                    }
                }
                GridRow {
                    label("切った声")
                    value("\(summary.voiceCuts.count) 回", PerfGrade.voiceCuts(summary.voiceCuts.count))
                }
                GridRow {
                    label("切った音")
                    value("\(summary.cuts.count) 回", .plain)
                }
            }
            if !summary.voiceCuts.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(summary.voiceCuts.prefix(6).enumerated()), id: \.offset) { _, cut in
                        Text(verbatim: cut.started
                             ? "\(cut.label)（残り \(String(format: "%.2f", cut.left))秒で）"
                             : "\(cut.label)（鳴る前に）")
                    }
                    if summary.voiceCuts.count > 6 {
                        Text(verbatim: "ほか \(summary.voiceCuts.count - 6) 回")
                    }
                }
                .foregroundStyle(.white.opacity(0.65))
                .padding(.top, 6)
                .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.15)).frame(height: 1) }
            }
            Button(action: restart) {
                Text(verbatim: "もう1回")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.12), in: .rect(cornerRadius: 8))
            }
            .padding(.top, 4)
        }
        .font(.system(size: 11, design: .monospaced))
        .foregroundStyle(.white)
        .padding(16)
        .background(.black.opacity(0.85), in: .rect(cornerRadius: 16))
    }

    private func label(_ s: String) -> some View {
        Text(verbatim: s).foregroundStyle(.white.opacity(0.5))
    }

    private func value(_ s: String, _ grade: PerfGrade) -> some View {
        Text(verbatim: s).foregroundStyle(grade.color).bold()
    }
}

private func ms(_ value: Double) -> String { "\(Int(value.rounded()))ms" }

/// 合格の線（docs/devops/perf-check）
enum PerfGrade {
    case ok, near, ng, plain

    var color: Color {
        switch self {
        case .ok: Color(red: 0.36, green: 0.89, blue: 0.54)
        case .near: Color(red: 1, green: 0.82, blue: 0.3)
        case .ng: Color(red: 1, green: 0.35, blue: 0.43)
        case .plain: .white
        }
    }

    /// 1秒の描画が100以上で合格。110未満は線の近く
    static func fps(_ v: Int) -> PerfGrade { v < 100 ? .ng : v < 110 ? .near : .ok }
    /// 50ms 以上の詰まりは0回で合格
    static func hitches(_ v: Int) -> PerfGrade { v == 0 ? .ok : .ng }
    /// タッチ→発火は最大40ms以下で合格。32ms を超えたら線の近く
    static func latency(_ v: Double) -> PerfGrade { v > 40 ? .ng : v > 32 ? .near : .ok }
    /// 声は1回も切らないで合格
    static func voiceCuts(_ v: Int) -> PerfGrade { v == 0 ? .ok : .ng }
}
#endif
