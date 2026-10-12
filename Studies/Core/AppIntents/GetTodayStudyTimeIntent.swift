//
//  GetTodayStudyTimeIntent.swift
//  Studies
//

import AppIntents
import SwiftData
import SwiftUI

struct GetTodayStudyTimeIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Today's Study Time"

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Measurement<UnitDuration>> & ProvidesDialog & ShowsSnippetView {
        let container = DIContainer.shared
        let todaySeconds = (try? await container.studyRecordUseCase.getTotalStudyTimeForToday()) ?? 0
        let todayMinutes = Int(todaySeconds / 60)

        // WidgetUpdateServiceと同じ手法で今日の目標を取得する
        let scheduleViewModel = ScheduleViewModel(container: container)
        await scheduleViewModel.loadData()
        let dailyGoalMinutes = scheduleViewModel.getTodayActiveSchedule()?.dailyGoalMinutes ?? 0

        let streakDays = AchievementService.calculateStreak(context: container.modelContainer.mainContext, subjectId: nil)

        let formattedTime = Self.formattedDuration(todaySeconds)
        let measurement = Measurement<UnitDuration>(value: Double(todayMinutes), unit: .minutes)

        let dialog: IntentDialog
        if dailyGoalMinutes > 0 {
            let percent = Int((Double(todayMinutes) / Double(dailyGoalMinutes) * 100).rounded())
            let formattedGoal = Self.formattedDuration(TimeInterval(dailyGoalMinutes * 60))
            let percentText = "\(percent)%"
            dialog = "You studied \(formattedTime) today — \(percentText) of your \(formattedGoal) goal."
        } else {
            dialog = "You studied \(formattedTime) today."
        }

        return .result(value: measurement, dialog: dialog) {
            TodayStudyTimeSnippetView(
                formattedTime: formattedTime,
                todayMinutes: todayMinutes,
                dailyGoalMinutes: dailyGoalMinutes,
                streakDays: streakDays
            )
        }
    }

    private static func formattedDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = duration < 60 ? [.minute, .second] : [.hour, .minute]
        return formatter.string(from: duration) ?? ""
    }
}

private struct TodayStudyTimeSnippetView: View {
    let formattedTime: String
    let todayMinutes: Int
    let dailyGoalMinutes: Int
    let streakDays: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today's Study Time")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(formattedTime)
                .font(.title.bold())

            if dailyGoalMinutes > 0 {
                let progress = Double(todayMinutes) / Double(dailyGoalMinutes)
                let percentText = "\(Int((progress * 100).rounded()))%"
                ProgressView(value: min(max(progress, 0), 1))
                Text("\(percentText) of your \(formattedGoal) goal")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if streakDays > 0 {
                Text("🔥 \(streakDays)-day streak")
                    .font(.subheadline)
            }
        }
        .padding()
    }

    private var formattedGoal: String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.hour, .minute]
        return formatter.string(from: TimeInterval(dailyGoalMinutes * 60)) ?? ""
    }
}
