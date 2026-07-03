//
// StudiesLiveActivityLiveActivity.swift
//
// 教材名とストップウォッチ経過時間を表示するLive Activity。
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
                    HStack(spacing: 10) {
                        SubjectIconView(color: subjectColor, size: 36, symbolSize: 16)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.attributes.subjectName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)

                            StatusLabel(isRunning: context.state.isRunning)
                        }
                    }
                    .padding(.leading, 4)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    ElapsedTimeText(state: context.state)
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(context.state.isRunning ? subjectColor : .secondary)
                        .frame(maxHeight: .infinity, alignment: .center)
                        .padding(.trailing, 4)
                }
            } compactLeading: {
                Image(systemName: context.state.isRunning ? "book.fill" : "pause.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(subjectColor)
            } compactTrailing: {
                ElapsedTimeText(state: context.state)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(context.state.isRunning ? subjectColor : .secondary)
                    .frame(maxWidth: 60)
            } minimal: {
                Image(systemName: context.state.isRunning ? "book.fill" : "pause.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(subjectColor)
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

    var body: some View {
        Group {
            if state.isRunning {
                Text(timerInterval: state.startDate...state.timerRangeEnd, countsDown: false)
            } else {
                Text(state.pausedFormattedTime)
            }
        }
        .monospacedDigit()
        .multilineTextAlignment(.trailing)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
}

// MARK: - Subject Icon

/// 教材カラーのグラデーションを敷いたアイコンタイル
struct SubjectIconView: View {
    let color: Color
    let size: CGFloat
    let symbolSize: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(color.gradient)

            Image(systemName: "book.fill")
                .font(.system(size: symbolSize, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Status Label

struct StatusLabel: View {
    let isRunning: Bool

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: isRunning ? "play.fill" : "pause.fill")
                .font(.system(size: 8, weight: .bold))

            Text(isRunning ? "学習中" : "一時停止")
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundStyle(.secondary)
    }
}

// MARK: - Lock Screen View

struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<StudyActivityAttributes>

    private var subjectColor: Color {
        Color(hex: context.attributes.subjectColor) ?? .accentColor
    }

    var body: some View {
        HStack(spacing: 14) {
            SubjectIconView(color: subjectColor, size: 44, symbolSize: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.subjectName)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                StatusLabel(isRunning: context.state.isRunning)
            }

            Spacer(minLength: 12)

            ElapsedTimeText(state: context.state)
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .foregroundStyle(context.state.isRunning ? .primary : .secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

// MARK: - Color Extension

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
