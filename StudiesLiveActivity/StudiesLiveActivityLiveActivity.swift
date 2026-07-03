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
                    // ヒーロー表示：中央に大きくタイマーを置く。
                    // 教材カラーが黒に近いと島の黒背景に埋もれるため常に白で表示する
                    ElapsedTimeText(state: context.state, alignment: .center)
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .opacity(context.state.isRunning ? 1.0 : 0.55)
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

/// Dynamic Islandのコンパクト表示用タイマー（フル表示）。
/// Text(timerInterval:)は利用可能な横幅いっぱいに広がるため、
/// 経過時間の桁数に合わせた固定幅を与えて余白が出ないようにする。
struct CompactTimerText: View {
    let state: StudyActivityAttributes.ContentState

    var body: some View {
        Group {
            if state.isRunning {
                Text(timerInterval: state.startDate...state.timerRangeEnd, countsDown: false)
                    .frame(width: timerWidth)
            } else {
                // 静的テキストは内容にぴったり収まるので幅指定不要
                Text(state.pausedFormattedTime)
            }
        }
        .font(.system(size: 13, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .multilineTextAlignment(.center)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    // 表示中の桁数（9:59 / 59:59 / 9:59:59）に応じた幅。
    // 桁が繰り上がった直後は次の再描画までminimumScaleFactorで吸収する
    private var timerWidth: CGFloat {
        let elapsed = Date().timeIntervalSince(state.startDate)
        switch elapsed {
        case ..<600: return 33
        case ..<3600: return 41
        default: return 56
        }
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
    subjectId: UUID(),
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
