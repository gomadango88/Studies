//
// EfficientStopwatchManager.swift
// Studies
//
// Created by takuma on 2025/08/08.
//

import Foundation
import SwiftUI
import Combine

@MainActor
@Observable
class EfficientStopwatchManager: StopwatchProtocol {
    var isRunning = false
    var elapsedTime: TimeInterval = 0
    private var startDate: Date?
    private(set) var accumulatedTime: TimeInterval = 0
    private var timerCancellable: AnyCancellable?
    private weak var activityManager: StudyActivityManager?    // Live Activity連携用
    private var currentSubject: Subject? // 教材への参照
    private let instanceId = UUID().uuidString.prefix(8)    // デバッグ用のID
    
    // MARK: - Public Methods
    
    func start() {
        guard !isRunning else {
            print("⚠️ [\(instanceId)] Already running, ignoring start")
            return
        }
        
        print("🟢 [\(instanceId)] Starting stopwatch")
        print("📊 [\(instanceId)] Current state: elapsed=\(elapsedTime), accumulated=\(accumulatedTime)")
        
        HapticFeedback.rigid()
        startDate = Date()
        isRunning = true
        
        print("📅 [\(instanceId)] Start date: \(startDate!)")
        
        // Apple推奨：10秒間隔に変更 + tolerance設定で省電力化
        timerCancellable = Timer.publish(every: 10.0, on: .main, in: .common)
            .autoconnect()
            .map { _ in Date() }
            .sink { [weak self] currentDate in
                guard let self = self else {
                    print("⚠️ self is nil in timer callback")
                    return
                }
                
                print("⏱️ [\(self.instanceId)] Timer tick: \(currentDate)")
                self.updateElapsedTime()
            }
        
        // 状態保存
        saveCurrentState()
    }
    
    func stop() {
        guard isRunning else {
            print("⚠️ [\(instanceId)] Not running, ignoring stop")
            return
        }
        
        print("🔴 [\(instanceId)] Stopping stopwatch")
        HapticFeedback.rigid()
        
        if let startDate = startDate {
            let sessionTime = Date().timeIntervalSince(startDate)
            accumulatedTime += sessionTime
            print("📊 [\(instanceId)] Session time: \(sessionTime), new accumulated: \(accumulatedTime)")
        }
        
        isRunning = false
        // Timer停止を優先実行
        timerCancellable?.cancel()
        timerCancellable = nil
        print("🛑 [\(instanceId)] Timer cancelled")
        
        updateElapsedTime()
        print("📊 [\(instanceId)] Final elapsed time: \(elapsedTime)")
        
        // Live Activity更新は後で実行
        activityManager?.updateActivity()
        
        // 状態保存
        saveCurrentState()
    }
    
    func reset() {
        print("🔄 [\(instanceId)] Resetting stopwatch")
        print("📊 [\(instanceId)] Before reset: elapsed=\(elapsedTime), accumulated=\(accumulatedTime)")
        
        HapticFeedback.rigid()
        
        // Timer停止を最優先
        timerCancellable?.cancel()
        timerCancellable = nil
        print("🛑 [\(instanceId)] Timer cancelled in reset")
        
        isRunning = false
        startDate = nil
        accumulatedTime = 0
        elapsedTime = 0
        
        print("📊 [\(instanceId)] After reset: elapsed=\(elapsedTime), accumulated=\(accumulatedTime)")
        
        // Live Activity終了
        activityManager?.handleReset()
        
        // 状態クリア
        clearSessionState()
    }
    
    // startWithLiveActivity メソッドを修正
    func startWithLiveActivity(for subject: Subject) {
        print("🚀 [\(instanceId)] Starting with Live Activity for subject: \(subject.name)")
        print("🚀 Current state - accumulated: \(accumulatedTime), elapsed: \(elapsedTime)")
        
        // 教材を設定
        setSubject(subject)
        
        // Live Activity開始前にtodayTotalTimeProviderが設定されていることを確認
        if StudyActivityManager.shared.todayTotalTimeProvider == nil {
            print("⚠️ todayTotalTimeProvider is not set, Live Activity may show 0:00")
            print("💡 Waiting for todayTotalTimeProvider setup...")
            
            // 少し待機してから再確認
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒待機
                if StudyActivityManager.shared.todayTotalTimeProvider != nil {
                    print("✅ todayTotalTimeProvider is now available")
                } else {
                    print("❌ todayTotalTimeProvider still not available after wait")
                }
            }
        }
        
        // 既存のライブアクティビティをチェック
        if StudyActivityManager.shared.isActivityActive {
            print("⚠️ Live Activity already active, updating instead of creating new one")
            start() // 内部のstart()のみ呼ぶ
            
            // 既存のアクティビティを更新
            Task { @MainActor in
                activityManager = StudyActivityManager.shared
                StudyActivityManager.shared.updateActivity()
            }
        } else {
            print("✅ No existing Live Activity, creating new one")
            start()
            
            // 新しいLive Activity開始
            Task { @MainActor in
                activityManager = StudyActivityManager.shared
                StudyActivityManager.shared.startActivity(for: subject, stopwatchManager: self)
            }
        }
    }

    
    // 教材設定メソッド
    func setSubject(_ subject: Subject) {
        print("📚 Setting subject for stopwatch: \(subject.name)")
        self.currentSubject = subject
    }
    
    // 内部状態設定メソッド（復元用）
    func setAccumulatedTime(_ time: TimeInterval) {
        print("🔧 Setting accumulated time to: \(time)")
        self.accumulatedTime = time
    }
    
    func setElapsedTime(_ time: TimeInterval) {
        print("🔧 Setting elapsed time to: \(time)")
        self.elapsedTime = time
    }
    
    // エラーハンドリング版で状態復元
    func restoreStateIfNeeded() {
        // StudySessionManagerを優先、エラー時はLiveActivityManagerを使用
        if let activeSession = tryGetStudySession() {
            restoreFromStudySession(activeSession)
        } else if let liveActivityState = LiveActivitySessionManager.shared.getLiveActivityState() {
            restoreFromLiveActivity(liveActivityState)
        }
    }
    
    // MARK: - Private Methods
    
    private func updateElapsedTime() {
        let oldTime = elapsedTime
        if let startDate = startDate, isRunning {
            elapsedTime = accumulatedTime + Date().timeIntervalSince(startDate)
        } else {
            elapsedTime = accumulatedTime
        }
        
        print("🔄 [\(instanceId)] Time update: \(oldTime) → \(elapsedTime)")
        
        // SystemFormatStyle.Stopwatchの更新のためのタイミング調整
        if let startDate = startDate, isRunning {
            let adjustedStartDate = startDate.addingTimeInterval(-accumulatedTime)
            print("📅 [\(instanceId)] Stopwatch start date: \(adjustedStartDate) (original: \(startDate), offset: -\(accumulatedTime))")
        }
    }
    
    // エラーハンドリング版で状態保存
    private func saveCurrentState() {
        guard let subject = currentSubject else {
            print("⚠️ No subject set for saving state")
            return
        }
        
        // 学習時間が記録されている場合のみ保存
        if elapsedTime > 0 || isRunning {
            print("💾 Saving current state - elapsed: \(elapsedTime), running: \(isRunning)")
            
            // メインアプリ用の保存
            saveToStudySessionManager(subject: subject)
            
            // Live Activity用の軽量保存
            LiveActivitySessionManager.shared.saveLiveActivityState(
                subjectId: subject.id,
                subjectName: subject.name,
                subjectColor: "#0066CC", // 簡易色
                elapsedTime: elapsedTime,
                isRunning: isRunning
            )
        } else {
            print("📭 No state to save (elapsed: \(elapsedTime), running: \(isRunning))")
        }
    }
    
    // StudySessionManager保存のエラーハンドリング
    private func saveToStudySessionManager(subject: Subject) {
        do {
            // StudySessionManagerが存在するかチェック（メインアプリでのみ動作）
            let _ = StudySessionManager.self // クラス存在チェック
            StudySessionManager.shared.saveActiveSession(subject: subject, stopwatchManager: self)
            print("✅ StudySessionManager save successful")
        } catch {
            print("⚠️ StudySessionManager not available (probably running in Extension): \(error)")
        }
    }
    
    // StudySession取得のエラーハンドリング
    private func tryGetStudySession() -> StudySessionState? {
        do {
            let _ = StudySessionManager.self // クラス存在チェック
            return StudySessionManager.shared.getActiveSession()
        } catch {
            print("⚠️ StudySessionManager not available for getting session: \(error)")
            return nil
        }
    }
    
    // エラーハンドリング版で状態クリア
    private func clearSessionState() {
        // StudySessionManager のクリア（エラーハンドリング付き）
        do {
            let _ = StudySessionManager.self // クラス存在チェック
            StudySessionManager.shared.clearActiveSession()
            print("✅ StudySessionManager cleared")
        } catch {
            print("⚠️ StudySessionManager not available for clearing: \(error)")
        }
        
        // LiveActivityManager のクリア（常に実行）
        LiveActivitySessionManager.shared.clearLiveActivityState()
    }
    
    // 完全な状態復元（エラーハンドリング付き）
    private func restoreFromStudySession(_ sessionState: StudySessionState) {
        print("🔄 Restoring from StudySessionState: \(sessionState.subjectName)")
        
        self.accumulatedTime = sessionState.accumulatedTime
        
        if sessionState.isRunning {
            let timeSinceLastUpdate = Date().timeIntervalSince(sessionState.lastUpdateTime)
            print("⏰ Time since last update: \(timeSinceLastUpdate) seconds")
            
            self.accumulatedTime += timeSinceLastUpdate
            self.isRunning = true
            self.startDate = Date()
            
            // タイマーを再開
            timerCancellable = Timer.publish(every: 10.0, on: .main, in: .common)
                .autoconnect()
                .map { _ in Date() }
                .sink { [weak self] _ in
                    self?.updateElapsedTime()
                }
            
            print("▶️ Resumed stopwatch with accumulated time: \(accumulatedTime)")
        }
        
        updateElapsedTime()
        print("✅ StudySession state restoration completed")
    }
    
    // Live Activity状態復元
    private func restoreFromLiveActivity(_ liveActivityState: LiveActivityState) {
        print("🔄 Restoring from LiveActivityState: \(liveActivityState.subjectName)")
        
        // より簡易的な復元
        self.elapsedTime = liveActivityState.elapsedTime
        self.isRunning = liveActivityState.isRunning
        
        if isRunning {
            let timeSinceLastUpdate = Date().timeIntervalSince(liveActivityState.lastUpdateTime)
            print("⏰ Time since last update: \(timeSinceLastUpdate) seconds")
            
            self.elapsedTime += timeSinceLastUpdate
            self.startDate = Date()
        }
        
        print("✅ LiveActivity state restoration completed")
    }
    
    // MARK: - Computed Properties
    
    var formattedTime: String {
        formatTimeInterval(elapsedTime)
    }
    
    // SystemFormatStyle.Stopwatch用のstartDate取得
    var stopwatchStartDate: Date? {
        if let startDate = startDate, isRunning {
            let adjustedStartDate = startDate.addingTimeInterval(-accumulatedTime)
            return adjustedStartDate
        }
        return nil
    }
    
    // --秒表示用のフォーマット
    var formattedTimeWithoutSeconds: String {
        let totalSeconds = Int(elapsedTime)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        
        if hours > 0 {
            return String(format: "%d:%02d:--", hours, minutes)
        } else {
            return String(format: "%d:--", minutes)
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
    
    deinit {
        print("💀 [\(instanceId)] EfficientStopwatchManager deinit called")
        print("💀 [\(instanceId)] Timer should be already cancelled")
    }
}
