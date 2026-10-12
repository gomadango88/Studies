//
// StudySessionViewModel.swift
// Studies
//
// Created by takuma on 2025/08/08.
//

import Foundation
import SwiftUI
import SwiftData
import os

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

    private(set) var subject: Subject

    var inputHours = 0
    var inputMinutes = 0

    var todayRecords: [StudyRecord] = []
    var isSaving = false
    // 保存・削除処理のエラー（アラート表示用）
    var errorMessage: String?
    // 今日の記録読み込みのエラー（保存エラーの表示とは独立して管理）
    var loadErrorMessage: String?

    var isInitialized = false
    var isLoading = false

    init(subject: Subject) {
        self.subject = subject
    }

    func setContainer(_ container: DIContainer, for subject: Subject) {
        self.diContainer = nil
        self.scheduleViewModel = nil

        self.subject = subject
        self.diContainer = container
        self.isInitialized = true
    }
    
    // MARK: - Computed Properties
    
    var todayTotalTimeText: String {
        let totalTime = todayRecords.reduce(0) { $0 + $1.duration }
        return formatTimeInterval(totalTime)
    }
    
    // MARK: - Methods
    
    func loadTodayRecords() async {
        guard let useCase = studyRecordUseCase else {
            loadErrorMessage = String(localized: "データの読み込み準備中です。しばらくお待ちください。")
            return
        }

        do {
            let today = Calendar.current.startOfDay(for: Date())
            let allRecords = try await useCase.getActiveRecordsForDate(today)

            todayRecords = allRecords.filter { record in
                record.subjectId == subject.id
            }

            // 読み込み成功時は読み込みエラーのみクリア（保存エラーの表示は保持する）
            loadErrorMessage = nil

        } catch {
            loadErrorMessage = String(localized: "今日の記録の読み込みに失敗しました: \(error.localizedDescription)")
            Logger.session.error("Error loading today records: \(error)")
        }
    }
    
    func saveStudyRecordWithStopwatch(inputHours: Int, inputMinutes: Int, stopwatchElapsed: TimeInterval) async -> Bool {
        
        guard let useCase = studyRecordUseCase else {
            errorMessage = String(localized: "学習記録の保存機能が利用できません")
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
                errorMessage = String(localized: "記録の保存に失敗しました: \(error.localizedDescription)")
            }
            Logger.session.error("Error saving record: \(error)")
            isSaving = false
            return false
        }
    }
    
    func deleteRecord(_ record: StudyRecord) async {
        guard let useCase = studyRecordUseCase else {
            errorMessage = String(localized: "削除機能が利用できません")
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
                errorMessage = String(localized: "記録の削除に失敗しました: \(error.localizedDescription)")
            }
            Logger.session.error("Error deleting record: \(error)")
        }
    }

    private func refreshAchievementsAndWidget() async {
        await loadTodayRecords()
        // スケジュールは1回だけロードして達成記録の更新で使い回す
        let schedule = await loadTodayActiveSchedule()
        await updateTodayAchievements(schedule: schedule)

        // 全体の合計時間・目標・連続日数の計算とウィジェット更新はWidgetUpdateServiceに一本化
        guard let container = diContainer else {
            return
        }
        await WidgetUpdateService.update(using: container)
    }

    // 今日のアクティブなスケジュールを1回のロードで取得
    private func loadTodayActiveSchedule() async -> StudySchedule? {
        guard let container = diContainer else {
            return nil
        }
        let viewModel = scheduleViewModel ?? ScheduleViewModel(container: container)
        scheduleViewModel = viewModel
        await viewModel.loadData()
        return viewModel.getTodayActiveSchedule()
    }

    private func updateTodayAchievements(schedule: StudySchedule?) async {
        guard let useCase = studyRecordUseCase else {
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
            Logger.session.error("Error updating overall achievement: \(error)")
        }
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
