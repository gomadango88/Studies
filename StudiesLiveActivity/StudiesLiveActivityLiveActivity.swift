//
// StudiesLiveActivityLiveActivity.swift
//
// 教材カラーを全面に敷いたカードスタイルのLive Activity。
// 実行中はText(timerInterval:)によるOS自動更新、一時停止中は静的表示。
//

import ActivityKit
import WidgetKit
import SwiftUI

struct StudiesLiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StudyActivityAttributes.self) { context in
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            let subjectColor = Color(hex: context.attributes.subjectColor) ?? .accentColor

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(subjectColor)
                            .frame(width: 9, height: 9)

                        Text(context.attributes.subjectName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .padding(.leading, 6)
                    .frame(maxHeight: .infinity, alignment: .center)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    StatusPill(isRunning: context.state.isRunning)
                        .padding(.trailing, 6)
                        .frame(maxHeight: .infinity, alignment: .center)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    // ヒーロー表示：中央に大きくタイマーを置く
                    ElapsedTimeText(state: context.state, alignment: .center)
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(context.state.isRunning ? subjectColor : .secondary)
                        .frame(maxWidth: .infinity)
                }
            } compactLeading: {
                SubjectTile(color: subjectColor, isRunning: context.state.isRunning, size: 18)
            } compactTrailing: {
                CompactTimerText(state: context.state)
                    .foregroundStyle(context.state.isRunning ? .primary : .secondary)
            } minimal: {
                SubjectTile(color: subjectColor, isRunning: context.state.isRunning, size: 18)
            }
            .keylineTint(subjectColor)
        }
        .configurationDisplayName("学習記録")
        .description("学習時間を追跡します。")
    }
}

// MARK: - Elapsed Time

/// 実行中はOSが自動更新するタイマー表示、一時停止中は固定した時間を表示する
struct ElapsedTimeText: View {
    let state: StudyActivityAttributes.ContentState
    var alignment: TextAlignment = .trailing

    var body: some View {
        Group {
            if state.isRunning {
                Text(timerInterval: state.startDate...state.timerRangeEnd, countsDown: false)
            } else {
                Text(state.pausedFormattedTime)
            }
        }
        .monospacedDigit()
        .multilineTextAlignment(alignment)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
}

// MARK: - Compact Timer

/// Dynamic Islandのコンパクト表示用タイマー。
/// 10分未満はm:ssのライブタイマー、10分以上は「15分」、1時間以上は「1時間」表示
/// （1:59:59までは1時間）。分・時間の数字はText(timerInterval:)の先頭桁だけを
/// clipして見せることで、アプリからの更新なしでもOSが繰り上がりを自動反映する。
struct CompactTimerText: View {
    let state: StudyActivityAttributes.ContentState

    // SF Rounded 13pt semibold monospacedDigitの実測幅（数字約8.85pt/桁）。
    // これより広げるとコロンの描画が漏れる
    private static let oneDigitClipWidth: CGFloat = 9.0
    private static let twoDigitClipWidth: CGFloat = 18.0

    var body: some View {
        Group {
            if state.isRunning {
                runningView
            } else {
                Text(pausedCompactText)
            }
        }
        .font(.system(size: 13, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .lineLimit(1)
    }

    @ViewBuilder
    private var runningView: some View {
        let elapsed = Date().timeIntervalSince(state.startDate)
        if elapsed < 600 {
            // m:ssライブ表示。10分到達後も次の再描画までは正確な時間を出し続ける
            Text(timerInterval: state.startDate...state.timerRangeEnd, countsDown: false)
                .frame(width: 33)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
        } else if elapsed < 3600 {
            // MM:SSの分2桁だけを表示。範囲終端59:59で凍結させ、
            // 再描画が来ないまま1時間を超えても表示が崩れないようにする
            unitClippedTimer(
                clipWidth: Self.twoDigitClipWidth,
                end: state.startDate.addingTimeInterval(59 * 60 + 59),
                unit: "分"
            )
        } else if elapsed < 36000 {
            // H:MM:SSの時間1桁だけを表示。終端9:59:59で凍結
            unitClippedTimer(
                clipWidth: Self.oneDigitClipWidth,
                end: state.startDate.addingTimeInterval(9 * 3600 + 59 * 60 + 59),
                unit: "時間"
            )
        } else {
            // 10時間以上は時間2桁
            unitClippedTimer(
                clipWidth: Self.twoDigitClipWidth,
                end: state.timerRangeEnd,
                unit: "時間"
            )
        }
    }

    private func unitClippedTimer(clipWidth: CGFloat, end: Date, unit: String) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 1) {
            Text(timerInterval: state.startDate...end, countsDown: false)
                .fixedSize()
                .frame(width: clipWidth, alignment: .leading)
                .clipped()

            Text(unit)
                .font(.system(size: 10, weight: .semibold))
        }
    }

    // 一時停止中は値が固定なので単純な文字列で同じ段階表示にする
    private var pausedCompactText: String {
        let seconds = Int(state.pausedElapsedTime)
        if seconds >= 3600 { return "\(seconds / 3600)時間" }
        if seconds >= 600 { return "\(seconds / 60)分" }
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

// MARK: - Subject Tile

/// 教材カラーの角丸タイル（Dynamic Islandのコンパクト/ミニマル表示用）
struct SubjectTile: View {
    let color: Color
    let isRunning: Bool
    let size: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(color.gradient)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: isRunning ? "book.fill" : "pause.fill")
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundStyle(.white)
            }
    }
}

// MARK: - Status Pill

/// 半透明カプセルの状態表示（学習中/一時停止）
struct StatusPill: View {
    let isRunning: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isRunning ? "play.fill" : "pause.fill")
                .font(.system(size: 8, weight: .bold))

            Text(isRunning ? "学習中" : "一時停止")
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(.white.opacity(0.18), in: Capsule())
    }
}

// MARK: - Lock Screen View

struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<StudyActivityAttributes>

    private var subjectColor: Color {
        Color(hex: context.attributes.subjectColor) ?? .accentColor
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // 教材カラーに溶け込む透かしシンボル
            Image(systemName: "book.fill")
                .font(.system(size: 68, weight: .bold))
                .foregroundStyle(.white.opacity(0.08))
                .rotationEffect(.degrees(-14))
                .offset(x: 14, y: 18)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center) {
                    Text(context.attributes.subjectName)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Spacer(minLength: 12)

                    StatusPill(isRunning: context.state.isRunning)
                        .foregroundStyle(.white)
                }

                ElapsedTimeText(state: context.state, alignment: .leading)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .opacity(context.state.isRunning ? 1.0 : 0.65)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(
            LinearGradient(
                colors: [subjectColor, subjectColor.darkened(0.35)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

// MARK: - Color Extensions

extension Color {
    init?(hex: String) {
        let r, g, b: Double
        if hex.hasPrefix("#") {
            let start = hex.index(hex.startIndex, offsetBy: 1)
            let hexColor = String(hex[start...])
            if hexColor.count == 6 {
                let scanner = Scanner(string: hexColor)
                var hexNumber: UInt64 = 0
                if scanner.scanHexInt64(&hexNumber) {
                    r = Double((hexNumber & 0xff0000) >> 16) / 255
                    g = Double((hexNumber & 0x00ff00) >> 8) / 255
                    b = Double(hexNumber & 0x0000ff) / 255
                    self.init(red: r, green: g, blue: b)
                    return
                }
            }
        }
        return nil
    }

    /// 明度を落とした色（背景グラデーションの終端に使う）
    func darkened(_ amount: Double) -> Color {
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        if UIColor(self).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            return Color(hue: hue, saturation: saturation, brightness: brightness * (1 - amount), opacity: alpha)
        }
        return self
    }
}

// MARK: - Previews

#Preview("Lock Screen", as: .content, using: StudyActivityAttributes(
    subjectName: "数学",
    subjectColor: "#0066CC",
    startTime: Date()
)) {
    StudiesLiveActivityLiveActivity()
} contentStates: {
    StudyActivityAttributes.ContentState(
        startDate: Date().addingTimeInterval(-1234),
        pausedDate: nil,
        isRunning: true
    )
    StudyActivityAttributes.ContentState(
        startDate: Date().addingTimeInterval(-1234),
        pausedDate: Date(),
        isRunning: false
    )
}
