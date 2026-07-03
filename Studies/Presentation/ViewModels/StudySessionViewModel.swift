//
// StudySessionViewModel.swift
// Studies
//
// Created by takuma on 2025/08/08.
//

import Foundation
import SwiftUI
import WidgetKit
import SwiftData

@MainActor
@Observable
class StudySessionViewModel {
    private var diContainer: DIContainer?
    
    private var modelContext: ModelContext? { diContainer?.modelContainer.mainContext }
    
    private var studyRecordUseCase: StudyRecordUseCaseProtocol? {
        diContainer?.studyRecordUseCase
    }

    // スケジュール読み込み用のViewModelを使い回す（保存のたびに複数回newしない）
    private var scheduleViewModel: ScheduleViewModel?

    // subjectは外部から変更不可
    private(set) var subject: Subject
    
    // 手動入力
    var inputHours = 0
    var inputMinutes = 0

    // 学習記録
    var todayRecords: [StudyRecord] = []
    var isSaving = false
    var errorMessage: String?
    
    // 初期化状態を追跡
    var isInitialized = false
    var isLoading = false
    
    init(subject: Subject) {
        self.subject = subject
    }
    
    // setContainerでsubject情報の同期を確実にする
    func setContainer(_ container: DIContainer, for subject: Subject) {
        // 前の状態をクリア
        self.diContainer = nil
        self.scheduleViewModel = nil

        // 新しい教材情報を設定
        self.subject = subject
        self.diContainer = container
        self.isInitialized = true

        // StudyActivityManagerに今日の合計時間プロバイダーを設定
        StudyActivityManager.shared.todayTotalTimeProvider = { [weak self] in
            guard let self = self else { return "0:00" }
            return await self.calculateFormattedTodayTotal()
        }
    }
    
    // 今日の合計時間をフォーマットして返すヘルパーメソッド
    private func calculateFormattedTodayTotal() async -> String {
        
        guard let useCase = studyRecordUseCase else {
            print("StudyRecordUseCase not available for today total")
            return "0:00"
        }
        
        do {
            let today = Calendar.current.startOfDay(for: Date())
            let allRecords = try await useCase.getActiveRecordsForDate(today)
            let totalSeconds = allRecords.reduce(0) { $0 + $1.duration }
            
            let hours = Int(totalSeconds) / 3600
            let minutes = Int(totalSeconds) % 3600 / 60
            
            let formattedTime: String
            if hours > 0 {
                formattedTime = String(format: "%d:%02d", hours, minutes)
            } else {
                formattedTime = String(format: "%d:%02d", 0, minutes)
            }
            
            return formattedTime
            
        } catch {
            print("Error calculating today total: \(error)")
            return "0:00"
        }
    }
    
    // MARK: - Computed Properties
    
    var todayTotalTimeText: String {
        let totalTime = todayRecords.reduce(0) { $0 + $1.duration }
        return formatTimeInterval(totalTime)
    }
    
    // MARK: - Methods
    
    func loadTodayRecords() async {
        guard let useCase = studyRecordUseCase else {
            print("StudyRecordUseCase not available")
            errorMessage = "データの読み込み準備中です。しばらくお待ちください。"
            return
        }

        do {
            let today = Calendar.current.startOfDay(for: Date())
            let allRecords = try await useCase.getActiveRecordsForDate(today)

            todayRecords = allRecords.filter { record in
                record.subjectId == subject.id
            }

            // 成功時にエラーメッセージをクリア
            if errorMessage == "データの読み込み準備中です。しばらくお待ちください。" {
                errorMessage = nil
            }

        } catch {
            errorMessage = "今日の記録の読み込みに失敗しました: \(error.localizedDescription)"
            print("Error loading today records: \(error)")
        }
    }
    
    func saveStudyRecordWithStopwatch(inputHours: Int, inputMinutes: Int, stopwatchElapsed: TimeInterval) async -> Bool {
        
        guard let useCase = studyRecordUseCase else {
            errorMessage = "学習記録の保存機能が利用できません"
            return false
        }
        
        let inputTime = TimeInterval(inputHours * 3600 + inputMinutes * 60)
        let totalTime = inputTime + stopwatchElapsed
        
        guard totalTime > 0 else { return false }
        
        isSaving = true
        errorMessage = nil
        
        do {
            _ = try await useCase.createRecord(
                subjectId: subject.id,
                duration: totalTime,
                studyDate: Date()
            )
            
            await refreshAchievementsAndWidget()
            
            isSaving = false
            return true
            
        } catch {
            if let useCaseError = error as? StudyRecordUseCaseError {
                errorMessage = useCaseError.errorDescription
            } else {
                errorMessage = "記録の保存に失敗しました: \(error.localizedDescription)"
            }
            print("Error saving record: \(error)")
            isSaving = false
            return false
        }
    }
    
    func deleteRecord(_ record: StudyRecord) async {
        guard let useCase = studyRecordUseCase else {
            errorMessage = "削除機能が利用できません"
            return
        }
        
        do {
            try await useCase.deleteRecord(record)
            await loadTodayRecords()
            
            await refreshAchievementsAndWidget()
            
        } catch {
            if let useCaseError = error as? StudyRecordUseCaseError {
                errorMessage = useCaseError.errorDescription
            } else {
                errorMessage = "記録の削除に失敗しました: \(error.localizedDescription)"
            }
            print("Error deleting record: \(error)")
        }
    }
    
    // 実際のスケジュール目標を取得するupdateWidgetData()
    private func updateWidgetData(schedule: StudySchedule?) async {

        guard diContainer != nil else {
            print("DIContainer not available for widget update")
            return
        }

        // 全教材の今日の合計時間を計算
        let totalTodayMinutes = await calculateTotalTodayMinutes()
        // 実際のスケジュール目標を取得
        let actualDailyGoal = schedule?.dailyGoalMinutes ?? 0
        // 実際の連続日数を取得
        let actualStreakDays = await getActualStreakDays()

        let widgetData = WidgetStudyGoalData(
            dailyGoal: actualDailyGoal,
            todayMinutes: totalTodayMinutes,
            streakDays: actualStreakDays,
            lastUpdated: Date()
        )

        WidgetDataManager.shared.saveWidgetData(widgetData)

        // ウィジェット更新をリクエスト
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func refreshAchievementsAndWidget() async {
        await loadTodayRecords()
        // スケジュールは1回だけロードして達成記録とウィジェット更新で使い回す
        let schedule = await loadTodayActiveSchedule()
        await updateTodayAchievements(schedule: schedule)
        await updateWidgetData(schedule: schedule)
    }

    // 今日のアクティブなスケジュールを1回のロードで取得
    private func loadTodayActiveSchedule() async -> StudySchedule? {
        guard let container = diContainer else {
            print("DIContainer not available, no schedule loaded")
            return nil
        }
        let viewModel = scheduleViewModel ?? ScheduleViewModel(container: container)
        scheduleViewModel = viewModel
        await viewModel.loadData()
        return viewModel.getTodayActiveSchedule()
    }

    private func updateTodayAchievements(schedule: StudySchedule?) async {
        guard let useCase = studyRecordUseCase else {
            print("StudyRecordUseCase not available for achievement update")
            return
        }

        guard let context = modelContext else { return }

        let today = Calendar.current.startOfDay(for: Date())
        let subjectMinutes = Int(todayRecords.reduce(0) { $0 + $1.duration } / 60)
        let subjectRequired = schedule?.subjectGoals
            .first(where: { $0.subjectId == subject.id && $0.isEnabled })?
            .goalMinutes ?? 0
        AchievementService.upsertAchievement(
            context: context,
            date: today,
            subjectId: subject.id,
            requiredMinutes: subjectRequired,
            achievedMinutes: subjectMinutes
        )

        do {
            let allRecords = try await useCase.getActiveRecordsForDate(today)
            let totalMinutes = Int(allRecords.reduce(0) { $0 + $1.duration } / 60)
            let overallRequired = schedule?.dailyGoalMinutes ?? 0
            AchievementService.upsertAchievement(
                context: context,
                date: today,
                subjectId: nil,
                requiredMinutes: overallRequired,
                achievedMinutes: totalMinutes
            )
        } catch {
            print("Error updating overall achievement: \(error)")
        }
    }
    
    // 全教材の今日の合計時間を計算
    private func calculateTotalTodayMinutes() async -> Int {
        
        guard let useCase = studyRecordUseCase else {
            print("StudyRecordUseCase not available")
            return 0
        }
        
        do {
            let today = Calendar.current.startOfDay(for: Date())
            let allRecords = try await useCase.getActiveRecordsForDate(today)
            let totalSeconds = allRecords.reduce(0) { $0 + $1.duration }
            let totalMinutes = Int(totalSeconds / 60)
            
            return totalMinutes
            
        } catch {
            print("Error calculating total today minutes: \(error)")
            return 0
        }
    }
    
    // 実際の連続日数を取得
    private func getActualStreakDays() async -> Int {
        guard let context = modelContext else { return 0 }
        return AchievementService.calculateStreak(context: context, subjectId: nil)
    }
    
    private func formatTimeInterval(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        let seconds = Int(timeInterval) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}
