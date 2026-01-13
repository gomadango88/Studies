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
    
    // subjectは外部から変更不可
    private(set) var subject: Subject
    
    // 手動入力
    var inputHours = 0
    var inputMinutes = 0
    
    // 新しいストップウォッチマネージャー
    let stopwatchManager = StopwatchManager()
    
    // Live Activity管理
    private let activityManager = StudyActivityManager.shared
    
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
        
        // 新しい教材情報を設定
        self.subject = subject
        self.diContainer = container
        self.isInitialized = true
        
        // ストップウォッチマネージャーにも教材を設定
        stopwatchManager.setSubject(subject)
        
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
            let allRecords = try await useCase.getRecordsForDate(today)
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
    
    var canSave: Bool {
        let inputTime = TimeInterval(inputHours * 3600 + inputMinutes * 60)
        return inputTime > 0 || stopwatchManager.elapsedTime > 0
    }
    
    // MARK: - Methods
    
    func loadTodayRecords() async {
        
        // studyRecordUseCaseの取得を再試行
        var useCase = studyRecordUseCase
        var retryCount = 0
        while useCase == nil && retryCount < 5 {
            try? await Task.sleep(nanoseconds: 50_000_000)
            useCase = studyRecordUseCase
            retryCount += 1
        }
        
        guard let useCase = useCase else {
            print("StudyRecordUseCase initialization failed after retries")
            errorMessage = "データの読み込み準備中です。しばらくお待ちください。"
            return
        }
        
        do {
            let today = Calendar.current.startOfDay(for: Date())
            let allRecords = try await useCase.getRecordsForDate(today)

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
    
    func saveStudyRecord() async {
        guard let useCase = studyRecordUseCase else {
            errorMessage = "学習記録の保存機能が利用できません"
            return
        }
        
        guard canSave else { return }
        
        isSaving = true
        errorMessage = nil
        
        let inputTime = TimeInterval(inputHours * 3600 + inputMinutes * 60)
        let totalTime = inputTime + stopwatchManager.elapsedTime
        
        do {
            _ = try await useCase.createRecord(
                subjectId: subject.id,
                duration: totalTime,
                studyDate: Date()
            )
            
            HapticFeedback.success()
            await activityManager.endActivity()
            inputHours = 0
            inputMinutes = 0
            stopwatchManager.reset()
            await loadTodayRecords()
            
            // Update daily achievements (subject and overall)
            let today = Calendar.current.startOfDay(for: Date())
            let subjectMinutes = Int(todayRecords.reduce(0) { $0 + $1.duration } / 60)
            let subjectRequired = await getTodaySubjectRequiredMinutes(subjectId: subject.id)
            upsertAchievement(for: today, subjectId: subject.id, requiredMinutes: subjectRequired, achievedMinutes: subjectMinutes)

            // Overall
            if let useCase = studyRecordUseCase {
                do {
                    let allRecords = try await useCase.getRecordsForDate(today)
                    let totalMinutes = Int(allRecords.reduce(0) { $0 + $1.duration } / 60)
                    let overallRequired = await getActualDailyGoalMinutes()
                    upsertAchievement(for: today, subjectId: nil, requiredMinutes: overallRequired, achievedMinutes: totalMinutes)
                } catch { }
            }
            
            // ウィジェットデータ更新
            await updateWidgetData()
            
        } catch {
            HapticFeedback.error()
            if let useCaseError = error as? StudyRecordUseCaseError {
                errorMessage = useCaseError.errorDescription
            } else {
                errorMessage = "記録の保存に失敗しました: \(error.localizedDescription)"
            }
            print("Error saving record: \(error)")
        }
        
        isSaving = false
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
            let savedRecord = try await useCase.createRecord(
                subjectId: subject.id,
                duration: totalTime,
                studyDate: Date()
            )
            
            // Update daily achievements (subject and overall)
            let today = Calendar.current.startOfDay(for: Date())
            let subjectMinutes = Int(todayRecords.reduce(0) { $0 + $1.duration } / 60)
            let subjectRequired = await getTodaySubjectRequiredMinutes(subjectId: subject.id)
            upsertAchievement(for: today, subjectId: subject.id, requiredMinutes: subjectRequired, achievedMinutes: subjectMinutes)

            // Overall
            if let useCase = studyRecordUseCase {
                do {
                    let allRecords = try await useCase.getRecordsForDate(today)
                    let totalMinutes = Int(allRecords.reduce(0) { $0 + $1.duration } / 60)
                    let overallRequired = await getActualDailyGoalMinutes()
                    upsertAchievement(for: today, subjectId: nil, requiredMinutes: overallRequired, achievedMinutes: totalMinutes)
                } catch { }
            }
            
            // ウィジェットデータ更新
            await updateWidgetData()
            
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
            
            // Update daily achievements (subject and overall)
            let today = Calendar.current.startOfDay(for: Date())
            let subjectMinutes = Int(todayRecords.reduce(0) { $0 + $1.duration } / 60)
            let subjectRequired = await getTodaySubjectRequiredMinutes(subjectId: subject.id)
            upsertAchievement(for: today, subjectId: subject.id, requiredMinutes: subjectRequired, achievedMinutes: subjectMinutes)

            // Overall
            if let useCase = studyRecordUseCase {
                do {
                    let allRecords = try await useCase.getRecordsForDate(today)
                    let totalMinutes = Int(allRecords.reduce(0) { $0 + $1.duration } / 60)
                    let overallRequired = await getActualDailyGoalMinutes()
                    upsertAchievement(for: today, subjectId: nil, requiredMinutes: overallRequired, achievedMinutes: totalMinutes)
                } catch { }
            }
            
            // ウィジェットデータ更新
            await updateWidgetData()
            
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
    private func updateWidgetData() async {
        
        guard let container = diContainer else {
            print("DIContainer not available for widget update")
            return
        }
        
        // 全教材の今日の合計時間を計算
        let totalTodayMinutes = await calculateTotalTodayMinutes()
        // 実際のスケジュール目標を取得
        let actualDailyGoal = await getActualDailyGoalMinutes()
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
    
    // 全教材の今日の合計時間を計算
    private func calculateTotalTodayMinutes() async -> Int {
        
        guard let useCase = studyRecordUseCase else {
            print("StudyRecordUseCase not available")
            return 0
        }
        
        do {
            let today = Calendar.current.startOfDay(for: Date())
            let allRecords = try await useCase.getRecordsForDate(today)
            let totalSeconds = allRecords.reduce(0) { $0 + $1.duration }
            let totalMinutes = Int(totalSeconds / 60)
            
            return totalMinutes
            
        } catch {
            print("Error calculating total today minutes: \(error)")
            return 0
        }
    }
    
    // 実際のスケジュール目標を取得
    private func getActualDailyGoalMinutes() async -> Int {
        
        guard let container = diContainer else {
            print("DIContainer not available, using default goal")
            return 0
        }
        
        do {
            // ScheduleViewModelを作成してスケジュールを取得
            let scheduleViewModel = ScheduleViewModel(container: container)
            await scheduleViewModel.loadData()
            let todaySchedule = scheduleViewModel.getTodayActiveSchedule()
            
            if let activeSchedule = todaySchedule {
                return activeSchedule.dailyGoalMinutes
            } else {
                print("No active schedule found, using default goal")
                return 0
            }
            
        } catch {
            print("Error getting schedule: \(error)")
            return 0
        }
    }
    
    // 実際の連続日数を取得
    private func getActualStreakDays() async -> Int {
        return calculateOverallStreakFromAchievements()
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
    
    // MARK: - Daily Achievement Persistence
    private func upsertAchievement(for date: Date, subjectId: UUID?, requiredMinutes: Int, achievedMinutes: Int) {
        guard let context = modelContext else { return }
        let key = DailyAchievementModel.makeKey(date: date, subjectId: subjectId)
        let descriptor = FetchDescriptor<DailyAchievementModel>(
            predicate: #Predicate { $0.key == key },
            sortBy: []
        )
        let achieved = achievedMinutes >= max(requiredMinutes, 0)
        do {
            if let existing = try context.fetch(descriptor).first {
                existing.requiredMinutes = requiredMinutes
                existing.achievedMinutes = achievedMinutes
                existing.achieved = achieved
                existing.computedAt = Date()
            } else {
                let model = DailyAchievementModel(
                    date: date,
                    subjectId: subjectId,
                    requiredMinutes: requiredMinutes,
                    achievedMinutes: achievedMinutes,
                    achieved: achieved,
                    computedAt: Date()
                )
                context.insert(model)
            }
            try context.save()
        } catch {
            print("[StudySessionVM] 達成状況の保存エラー: \(error)")
        }
    }

    private func calculateOverallStreakFromAchievements() -> Int {
        guard let context = modelContext else { return 0 }
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())

        func achievement(on date: Date) -> DailyAchievementModel? {
            let key = DailyAchievementModel.makeKey(date: date, subjectId: nil)
            let descriptor = FetchDescriptor<DailyAchievementModel>(
                predicate: #Predicate { $0.key == key },
                sortBy: []
            )
            return try? context.fetch(descriptor).first
        }

        let startDate: Date = {
            if let rec = achievement(on: todayStart), rec.achieved {
                return todayStart
            } else {
                return calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
            }
        }()

        var date = startDate
        var count = 0
        for _ in 0..<365 {
            guard let rec = achievement(on: date) else { break }
            if rec.achieved {
                count += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: date) else { break }
                date = prev
            } else {
                break
            }
        }
        return count
    }

    private func getTodaySubjectRequiredMinutes(subjectId: UUID) async -> Int {
        guard let container = diContainer else { return 0 }
        let scheduleVM = ScheduleViewModel(container: container)
        await scheduleVM.loadData()
        if let schedule = scheduleVM.getTodayActiveSchedule(),
           let goal = schedule.subjectGoals.first(where: { $0.subjectId == subjectId && $0.isEnabled }) {
            return goal.goalMinutes
        }
        return 0
    }
}

// MARK: - StopwatchManager Extension
extension StopwatchManager {
    func setSubject(_ subject: Subject) {
        // StopwatchManagerに教材情報を設定する処理
        // 必要に応じて実装
    }
}

