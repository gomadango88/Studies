//
// WidgetUpdateService.swift
// Studies
//
// Centralized widget update logic.
//

import Foundation
import SwiftUI
import WidgetKit

struct WidgetUpdateService {
    static func update(using container: DIContainer) async {
        print("🧩 WidgetUpdateService: start update")
        // 1) 今日の合計分
        let studyRecordUseCase = container.studyRecordUseCase
        let totalTodayMinutes: Int
        do {
            let totalTodaySeconds = try await studyRecordUseCase.getTotalStudyTimeForToday()
            totalTodayMinutes = Int(totalTodaySeconds / 60)
            print("🧩 todayMinutes: \(totalTodayMinutes)")
        } catch {
            print("❌ WidgetUpdateService: getTotalStudyTimeForToday error: \(error)")
            totalTodayMinutes = 0
        }

        // 2) 今日の目標分（スケジュール）
        let dailyGoal: Int
        do {
            let scheduleVM = ScheduleViewModel(container: container)
            await scheduleVM.loadData()
            dailyGoal = scheduleVM.getTodayActiveSchedule()?.dailyGoalMinutes ?? 0
            print("🧩 dailyGoal: \(dailyGoal)")
        } catch {
            print("❌ WidgetUpdateService: schedule load error: \(error)")
            dailyGoal = 0
        }

        // 3) 連続日数
        let streakDays: Int
        do {
            let days = try await studyRecordUseCase.getOverallConsecutiveStudyDays()
            streakDays = days
            print("🧩 streakDays: \(streakDays)")
        } catch {
            print("❌ WidgetUpdateService: streak error: \(error)")
            streakDays = 0
        }

        // 4) 保存してリロード
        let data = WidgetStudyGoalData(
            dailyGoal: dailyGoal,
            todayMinutes: totalTodayMinutes,
            streakDays: streakDays,
            lastUpdated: Date()
        )
        WidgetDataManager.shared.saveWidgetData(data)
        WidgetCenter.shared.reloadAllTimelines()
        print("✅ WidgetUpdateService: finished update")
    }
}
