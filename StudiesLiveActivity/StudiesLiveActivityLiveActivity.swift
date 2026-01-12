//
// StudiesLiveActivityLiveActivity.swift（今日の合計データ対応版）
//

import ActivityKit
import WidgetKit
import SwiftUI

struct StudiesLiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StudyActivityAttributes.self) { context in
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // 適切な余白を追加
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(hex: context.attributes.subjectColor) ?? .blue)
                            .frame(width: 3, height: 35)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(context.attributes.subjectName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            
                            Text("学習中")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.leading, 8) // 左側の余白
                    .padding(.vertical, 4)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("今日の合計")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        // 実際のデータを使用
                        Text(context.state.todayTotalTime)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(.primary)
                    }
                    .padding(.trailing, 8) // 右側の余白
                    .padding(.vertical, 4)
                }
                
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 3) {
                        Text(context.state.formattedTime)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 4) {
                            Circle()
                                .fill(context.state.isRunning ? .green : .orange)
                                .frame(width: 5, height: 5)
                            
                            Text(context.state.isRunning ? "実行中" : "一時停止")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(context.state.isRunning ? .green : .orange)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // bottomセクションを削除（プログレスバー不要）
                
            } compactLeading: {
                Circle()
                    .fill(Color(hex: context.attributes.subjectColor) ?? .blue)
                    .frame(width: 22, height: 22)
                    .overlay(
                        Image(systemName: context.state.isRunning ? "play.fill" : "pause.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    )
            } compactTrailing: {
                Text(context.state.formattedTime)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
            } minimal: {
                ZStack {
                    Circle()
                        .fill(Color(hex: context.attributes.subjectColor) ?? .blue)
                        .frame(width: 22, height: 22)
                    
                    Image(systemName: context.state.isRunning ? "play.fill" : "pause.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .configurationDisplayName("学習記録")
        .description("学習時間を追跡します。")
    }
}

// MARK: - Lock Screen View
struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<StudyActivityAttributes>
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: context.attributes.subjectColor) ?? .blue)
                    .frame(width: 4, height: 16)
                
                Text(context.attributes.subjectName)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(context.state.isRunning ? "学習中" : "一時停止")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text(context.state.formattedTime)
                    .font(.system(.title, design: .rounded))
                    .fontWeight(.bold)
                    .monospacedDigit()
                
                Spacer()
                
                Image(systemName: context.state.isRunning ? "play.circle" : "pause.circle")
                    .font(.title2)
                    .foregroundColor(context.state.isRunning ? .green : .orange)
            }
        }
        .padding()
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

#Preview("Notification", as: .content, using: StudyActivityAttributes(
    subjectName: "数学",
    subjectColor: "#0066CC",
    startTime: Date()
)) {
    StudiesLiveActivityLiveActivity()
} contentStates: {
    StudyActivityAttributes.ContentState(
        elapsedTime: 1234,
        isRunning: true,
        lastUpdateTime: Date(),
        todayTotalTime: "2:30:15" // プレビュー用のサンプル値
    )
}

