//
// StudyGoalWidget.swift
// StudiesWidget
//

import WidgetKit
import SwiftUI

// MARK: - Widget Entry

struct StudyGoalEntry: TimelineEntry {
    let date: Date
    let dailyGoal: Int
    let todayMinutes: Int
    let streakDays: Int
    let isAchieved: Bool
    let hasValidGoal: Bool
    
    static let sample = StudyGoalEntry(
        date: Date(),
        dailyGoal: 120,
        todayMinutes: 75,
        streakDays: 5,
        isAchieved: false,
        hasValidGoal: true
    )
}

// MARK: - Widget専用 Custom Progress Bar

struct WidgetCustomProgressBar: View {
    let progress: CGFloat
    let color: Color
    let height: CGFloat
    let cornerRadius: CGFloat
    let useGradient: Bool = true
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(.systemGray5))
                
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(progressBarFill)
                    .frame(width: geometry.size.width * max(0, min(1, progress)))
                    .animation(.easeInOut(duration: 0.7), value: progress)
            }
        }
        .frame(height: height)
    }
    
    private var progressBarFill: some ShapeStyle {
        if useGradient {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        color.opacity(0.65),
                        color,
                        color.opacity(0.95)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        } else {
            return AnyShapeStyle(color)
        }
    }
}

// MARK: - Widget Views（タップ遷移対応）

struct StudyGoalWidgetEntryView: View {
    var entry: StudyGoalEntry
    @Environment(\.widgetFamily) var family
    
    private var achievementPercentage: Int {
        guard entry.dailyGoal > 0 else { return 0 }
        let percentage = Double(entry.todayMinutes) / Double(entry.dailyGoal) * 100
        return Int(min(percentage, 100))
    }
    
    private var progressValue: Double {
        guard entry.dailyGoal > 0 else { return 0 }
        return min(Double(entry.todayMinutes) / Double(entry.dailyGoal), 1.0)
    }
    
    var body: some View {
        Link(destination: URL(string: "studies://studygoal")!) {
            Group {
                switch family {
                case .systemSmall:
                    smallWidgetView
                case .systemMedium:
                    mediumWidgetView
                default:
                    smallWidgetView
                }
            }
        }
    }
    
    private var smallWidgetView: some View {
        VStack(spacing: 8) {
            if entry.hasValidGoal {
                VStack(spacing: 6) {
                    Text("今日の学習")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("\(entry.todayMinutes) / \(entry.dailyGoal) 分")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 4) {
                        if achievementPercentage == 100 {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 14))
                        }
                        Text("\(achievementPercentage)%")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    if entry.streakDays > 0 {
                        Text("目標達成: \(entry.streakDays)日連続")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.orange)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Spacer()

                    Image(systemName: "target")
                        .font(.system(size: 24))
                        .foregroundColor(.orange)
                    
                    VStack(spacing: 4) {
                        Text("目標未設定")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("スケジュールを\n設定してください")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var mediumWidgetView: some View {
        VStack(spacing: 16) {
            if entry.hasValidGoal {
                HStack {
                    VStack(alignment: .leading) {
                        Text("今日の学習")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Text("\(entry.todayMinutes) / \(entry.dailyGoal) 分")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: entry.isAchieved ? "checkmark.circle.fill" : "clock")
                        .font(.system(size: 30))
                        .foregroundColor(entry.isAchieved ? .green : .orange)
                }
                
                WidgetCustomProgressBar(
                    progress: progressValue,
                    color: .purple,
                    height: 10,
                    cornerRadius: 6
                )
                
                HStack {
                    Text("\(achievementPercentage)% 達成")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("目標達成: \(entry.streakDays)日連続")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                }
            } else {
                VStack(spacing: 16) {
                    Spacer()

                    Image(systemName: "target")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    
                    VStack(spacing: 8) {
                        Text("目標時間が設定されていません")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                        
                        Text("タップして学習スケジュールを設定")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(16)
    }
}

// MARK: - Timeline Provider

struct StudyGoalProvider: TimelineProvider {
    func placeholder(in context: Context) -> StudyGoalEntry {
        StudyGoalEntry.sample
    }
    
    func getSnapshot(in context: Context, completion: @escaping (StudyGoalEntry) -> ()) {
        Task {
            let entry = await fetchCurrentStudyGoalData()
            completion(entry)
        }
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<StudyGoalEntry>) -> ()) {
        Task {
            let entry = await fetchCurrentStudyGoalData()

            // アプリ側がデータ更新時にWidgetCenter.reloadTimelines(またはreloadAllTimelines)を
            // 呼び出して即時反映するため、タイムライン自体の定期更新は日付が変わるタイミングのみでよい。
            // 短い間隔での再スケジュールはWidgetKitの更新バジェットを浪費するため避ける。
            let nextMidnight = Calendar.current.nextDate(
                after: Date(),
                matching: DateComponents(hour: 0, minute: 0, second: 0),
                matchingPolicy: .nextTime
            ) ?? Date().addingTimeInterval(24 * 60 * 60)
            let timeline = Timeline(entries: [entry], policy: .after(nextMidnight))

            completion(timeline)
        }
    }
    
    private func fetchCurrentStudyGoalData() async -> StudyGoalEntry {
        if let widgetData = WidgetDataManager.shared.loadWidgetData() {
            let hasValidGoal = widgetData.dailyGoal > 0

            return StudyGoalEntry(
                date: Date(),
                dailyGoal: widgetData.dailyGoal,
                todayMinutes: widgetData.todayMinutes,
                streakDays: widgetData.streakDays,
                isAchieved: widgetData.isAchieved,
                hasValidGoal: hasValidGoal
            )
        } else {
            return StudyGoalEntry(
                date: Date(),
                dailyGoal: 0,
                todayMinutes: 0,
                streakDays: 0,
                isAchieved: false,
                hasValidGoal: false
            )
        }
    }
}

// MARK: - Widget Configuration

struct StudyGoalWidget: Widget {
    let kind: String = "StudyGoalWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StudyGoalProvider()) { entry in
            StudyGoalWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("今日の学習目標")
        .description("今日の学習目標の進捗を表示します。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    StudyGoalWidget()
} timeline: {
    StudyGoalEntry.sample
    StudyGoalEntry(
        date: Date(),
        dailyGoal: 120,
        todayMinutes: 90,
        streakDays: 10,
        isAchieved: false,
        hasValidGoal: true
    )
    StudyGoalEntry(
        date: Date(),
        dailyGoal: 0,
        todayMinutes: 0,
        streakDays: 0,
        isAchieved: false,
        hasValidGoal: false
    )
}

#Preview(as: .systemMedium) {
    StudyGoalWidget()
} timeline: {
    StudyGoalEntry.sample
    StudyGoalEntry(
        date: Date(),
        dailyGoal: 120,
        todayMinutes: 120,
        streakDays: 7,
        isAchieved: true,
        hasValidGoal: true
    )
    StudyGoalEntry(
        date: Date(),
        dailyGoal: 0,
        todayMinutes: 0,
        streakDays: 0,
        isAchieved: false,
        hasValidGoal: false
    )
}

