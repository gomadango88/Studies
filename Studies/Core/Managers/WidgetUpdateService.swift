//
// WidgetUpdateService.swift
// Studies
//
// Created by takuma on 2025/08/08.
//

import Foundation
import SwiftData
import WidgetKit
import os

// ウィジェット更新処理を一元化するサービス
struct WidgetUpdateService {
    static func update(using container: DIContainer) async {
        // 1) 今日の合計分
        let studyRecordUseCase = container.studyRecordUseCase
        let totalTodayMinutes: Int
        do {
            let totalTodaySeconds = try await studyRecordUseCase.getTotalStudyTimeForToday()
            totalTodayMinutes = Int(totalTodaySeconds / 60)

        } catch {
            Logger.widget.error("getTotalStudyTimeForToday error: \(error)")
            totalTodayMinutes = 0
        }

        // 2) 今日の目標分（スケジュール）
        let dailyGoal: Int
        let scheduleVM = ScheduleViewModel(container: container)
        await scheduleVM.loadData()
        dailyGoal = scheduleVM.getTodayActiveSchedule()?.dailyGoalMinutes ?? 0

        // 3) コンテキストと日付を定義
        let context = container.modelContainer.mainContext
        let todayStart = Calendar.current.startOfDay(for: Date())

        // 3) 達成状況のアップサート（条件付き）
        // 有効スケジュールがある日、または今日に学習がある日のみ記録をアップサート
        if dailyGoal > 0 || totalTodayMinutes > 0 {
            AchievementService.upsertAchievement(context: context, date: todayStart, subjectId: nil, requiredMinutes: dailyGoal, achievedMinutes: totalTodayMinutes)
        }

        // 4) 連続日数（目標達成ベース）
        let streakDays = AchievementService.calculateStreak(context: context, subjectId: nil)

        // 5) 保存してリロード
        let data = WidgetStudyGoalData(
            dailyGoal: dailyGoal,
            todayMinutes: totalTodayMinutes,
            streakDays: streakDays,
            lastUpdated: Date()
        )
        WidgetDataManager.shared.saveWidgetData(data)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
