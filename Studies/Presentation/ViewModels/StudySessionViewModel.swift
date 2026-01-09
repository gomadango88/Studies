//
// StudySessionViewModel.swift
// Studies
//
// Created by takuma on 2025/08/08.
//

import Foundation
import SwiftUI
import WidgetKit // 🔥 追加: ウィジェット更新用

@MainActor
@Observable
class StudySessionViewModel {
    private var diContainer: DIContainer?
    
    private var studyRecordUseCase: StudyRecordUseCaseProtocol? {
        diContainer?.studyRecordUseCase
    }
    
    // 🔥 修正: subjectをprivate setにして外部からの変更を防止
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
        print("🏗️ StudySessionViewModel init for subject: \(subject.name) (ID: \(subject.id))")
    }
    
    // 🔥 修正: setContainerでsubject情報の同期を確実にする
    func setContainer(_ container: DIContainer, for subject: Subject) {
        print("📦 Setting container for subject: \(subject.name) (ID: \(subject.id))")
        // 🔥 重要: 前の状態を完全にクリーンアップ
        self.diContainer = nil
        
        // 🔥 新しい教材情報を確実に設定
        self.subject = subject
        self.diContainer = container
        self.isInitialized = true
        
        // 🔥 ストップウォッチマネージャーにも正しい教材を設定
        stopwatchManager.setSubject(subject)
        
        // 🔥 追加: StudyActivityManagerに今日の合計時間プロバイダーを設定
        StudyActivityManager.shared.todayTotalTimeProvider = { [weak self] in
            guard let self = self else { return "0:00" }
            return await self.calculateFormattedTodayTotal()
        }
        
        print("✅ Container and subject synchronized for: \(subject.name) (ID: \(subject.id))")
        print("✅ Today total time provider set for Live Activity")
    }
    
    // 🔥 追加: 今日の合計時間をフォーマットして返すヘルパーメソッド
    private func calculateFormattedTodayTotal() async -> String {
        print("📊 Calculating formatted today total...")
        
        guard let useCase = studyRecordUseCase else {
            print("⚠️ StudyRecordUseCase not available for today total")
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
            
            print("✅ Today total calculated: \(formattedTime) from \(allRecords.count) records (\(totalSeconds) seconds)")
            return formattedTime
            
        } catch {
            print("❌ Error calculating today total: \(error)")
            return "0:00"
        }
    }
    
    // MARK: - Computed Properties
    
    var todayTotalTimeText: String {
        let totalTime = todayRecords.reduce(0) { $0 + $1.duration }
        print("📊 Computing total time for \(subject.name) (ID: \(subject.id)): \(totalTime) seconds from \(todayRecords.count) records")
        
        // 各記録の詳細をログ出力
        for (index, record) in todayRecords.enumerated() {
            print("📊 Record \(index + 1): subjectId=\(record.subjectId), duration=\(record.duration)s, date=\(record.studyDate)")
        }
        
        return formatTimeInterval(totalTime)
    }
    
    var canSave: Bool {
        let inputTime = TimeInterval(inputHours * 3600 + inputMinutes * 60)
        return inputTime > 0 || stopwatchManager.elapsedTime > 0
    }
    
    // MARK: - Methods
    
    func loadTodayRecords() async {
        print("🔍 Loading today records for subject: \(subject.name) (ID: \(subject.id))")
        
        // studyRecordUseCaseの取得を再試行
        var useCase = studyRecordUseCase
        var retryCount = 0
        while useCase == nil && retryCount < 5 {
            print("StudyRecordUseCase is nil, retrying... (\(retryCount + 1)/5)")
            try? await Task.sleep(nanoseconds: 50_000_000)
            useCase = studyRecordUseCase
            retryCount += 1
        }
        
        guard let useCase = useCase else {
            print("❌ StudyRecordUseCase initialization failed after retries")
            errorMessage = "データの読み込み準備中です。しばらくお待ちください。"
            return
        }
        
        do {
            let today = Calendar.current.startOfDay(for: Date())
            print("📅 Loading records for date: \(today)")
            let allRecords = try await useCase.getRecordsForDate(today)
            print("📊 Total records for today: \(allRecords.count)")
            
            // 🔥 修正: より厳密なフィルタリング
            let originalCount = todayRecords.count
            todayRecords = allRecords.filter { record in
                let matches = record.subjectId == subject.id
                if !matches {
                    print("🔍 Excluding record: subjectId=\(record.subjectId), duration=\(record.duration)s, targetSubjectId=\(subject.id)")
                } else {
                    print("✅ Including record: subjectId=\(record.subjectId), duration=\(record.duration)s")
                }
                return matches
            }
            
            print("✅ Filtered records for \(subject.name): \(todayRecords.count) (was: \(originalCount))")
            print("📊 Total time for \(subject.name): \(todayRecords.reduce(0) { $0 + $1.duration }) seconds")
            
            // 成功時にエラーメッセージをクリア
            if errorMessage == "データの読み込み準備中です。しばらくお待ちください。" {
                errorMessage = nil
            }
            
        } catch {
            errorMessage = "今日の記録の読み込みに失敗しました: \(error.localizedDescription)"
            print("❌ Error loading today records: \(error)")
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
            
            // 🔥 追加: ウィジェットデータ更新
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
        print("💾 saveStudyRecordWithStopwatch called for subject: \(subject.name) (ID: \(subject.id))")
        
        guard let useCase = studyRecordUseCase else {
            errorMessage = "学習記録の保存機能が利用できません"
            return false
        }
        
        let inputTime = TimeInterval(inputHours * 3600 + inputMinutes * 60)
        let totalTime = inputTime + stopwatchElapsed
        print("💾 Saving record: inputTime=\(inputTime)s, stopwatchTime=\(stopwatchElapsed)s, totalTime=\(totalTime)s")
        
        guard totalTime > 0 else { return false }
        
        isSaving = true
        errorMessage = nil
        
        do {
            let savedRecord = try await useCase.createRecord(
                subjectId: subject.id, // 🔥 確実にsubject.idを使用
                duration: totalTime,
                studyDate: Date()
            )
            
            print("✅ Successfully saved record: ID=\(savedRecord.id), subjectId=\(savedRecord.subjectId), duration=\(savedRecord.duration)s")
            
            // 🔥 追加: ウィジェットデータ更新
            await updateWidgetData()
            
            isSaving = false
            return true
            
        } catch {
            if let useCaseError = error as? StudyRecordUseCaseError {
                errorMessage = useCaseError.errorDescription
            } else {
                errorMessage = "記録の保存に失敗しました: \(error.localizedDescription)"
            }
            print("❌ Error saving record: \(error)")
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
            
            // 🔥 追加: ウィジェットデータ更新
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
    
    // 🔥 実際のスケジュール目標を取得するupdateWidgetData()
    private func updateWidgetData() async {
        print("📱 Updating widget data with actual schedule goal...")
        
        guard let container = diContainer else {
            print("❌ DIContainer not available for widget update")
            return
        }
        
        // 🔥 全教材の今日の合計時間を計算
        let totalTodayMinutes = await calculateTotalTodayMinutes()
        // 🔥 実際のスケジュール目標を取得
        let actualDailyGoal = await getActualDailyGoalMinutes()
        // 🔥 実際の連続日数を取得
        let actualStreakDays = await getActualStreakDays()
        
        let widgetData = WidgetStudyGoalData(
            dailyGoal: actualDailyGoal,
            todayMinutes: totalTodayMinutes,
            streakDays: actualStreakDays,
            lastUpdated: Date()
        )
        
        print("📱 Widget data with actual values: \(widgetData)")
        WidgetDataManager.shared.saveWidgetData(widgetData)
        
        // ウィジェット更新をリクエスト
        WidgetCenter.shared.reloadAllTimelines()
        print("✅ Widget updated - Goal: \(actualDailyGoal)min, Today: \(totalTodayMinutes)min, Streak: \(actualStreakDays)days")
    }
    
    // 🔥 全教材の今日の合計時間を計算
    private func calculateTotalTodayMinutes() async -> Int {
        print("📊 Calculating total today minutes for all subjects...")
        
        guard let useCase = studyRecordUseCase else {
            print("⚠️ StudyRecordUseCase not available")
            return 0
        }
        
        do {
            let today = Calendar.current.startOfDay(for: Date())
            let allRecords = try await useCase.getRecordsForDate(today)
            let totalSeconds = allRecords.reduce(0) { $0 + $1.duration }
            let totalMinutes = Int(totalSeconds / 60)
            
            print("✅ Total today minutes for all subjects: \(totalMinutes) minutes from \(allRecords.count) records")
            return totalMinutes
            
        } catch {
            print("❌ Error calculating total today minutes: \(error)")
            return 0
        }
    }
    
    // 🔥 実際のスケジュール目標を取得
    private func getActualDailyGoalMinutes() async -> Int {
        print("📊 Getting actual daily goal from schedule...")
        
        guard let container = diContainer else {
            print("⚠️ DIContainer not available, using default goal")
            return 0
        }
        
        do {
            // ScheduleViewModelを作成してスケジュールを取得
            let scheduleViewModel = ScheduleViewModel(container: container)
            await scheduleViewModel.loadData()
            let todaySchedule = scheduleViewModel.getTodayActiveSchedule()
            
            if let activeSchedule = todaySchedule {
                print("✅ Found active schedule with daily goal: \(activeSchedule.dailyGoalMinutes) minutes")
                return activeSchedule.dailyGoalMinutes
            } else {
                print("⚠️ No active schedule found, using default goal")
                return 0
            }
            
        } catch {
            print("❌ Error getting schedule \(error)")
            return 0
        }
    }
    
    // 🔥 実際の連続日数を取得
    private func getActualStreakDays() async -> Int {
        print("📊 Getting actual streak days...")
        
        guard let useCase = studyRecordUseCase else {
            print("⚠️ StudyRecordUseCase not available")
            return 0
        }
        
        do {
            let streakDays = try await useCase.getOverallConsecutiveStudyDays()
            print("✅ Actual streak days: \(streakDays)")
            return streakDays
            
        } catch {
            print("❌ Error getting streak days: \(error)")
            return 0
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

// MARK: - StopwatchManager Extension
extension StopwatchManager {
    func setSubject(_ subject: Subject) {
        print("📚 Setting subject for stopwatch: \(subject.name)")
        // StopwatchManagerに教材情報を設定する処理
        // 必要に応じて実装
    }
}
