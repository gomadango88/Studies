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
    
    // MARK: - Public Methods
    
    func start() {
        guard !isRunning else {
            return
        }
        
        HapticFeedback.rigid()
        startDate = Date()
        isRunning = true
        
        // Apple推奨：10秒間隔に変更 + tolerance設定で省電力化
        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .map { _ in Date() }
            .sink { [weak self] currentDate in
                guard let self = self else {
                    return
                }

                let previousElapsed = self.elapsedTime
                self.updateElapsedTime()
                self.refreshActivityOnDisplayBoundary(previous: previousElapsed, current: self.elapsedTime)
            }
        
        // 状態保存
        saveCurrentState()
    }
    
    func stop() {
        guard isRunning else {
            return
        }
        
        HapticFeedback.rigid()
        
        if let startDate = startDate {
            let sessionTime = Date().timeIntervalSince(startDate)
            accumulatedTime += sessionTime
        }
        
        isRunning = false
        // Timer停止を優先実行
        timerCancellable?.cancel()
        timerCancellable = nil
        
        updateElapsedTime()
        
        // Live Activity更新は後で実行
        activityManager?.updateActivity()
        
        // 状態保存
        saveCurrentState()
    }
    
    func reset() {
        HapticFeedback.rigid()
        
        // Timer停止を最優先
        timerCancellable?.cancel()
        timerCancellable = nil
        
        isRunning = false
        startDate = nil
        accumulatedTime = 0
        elapsedTime = 0
        
        // Live Activity終了
        activityManager?.handleReset()
        
        // 状態クリア
        clearSessionState()
    }
    
    func startWithLiveActivity(for subject: Subject) {
        // 教材を設定
        setSubject(subject)

        start()

        activityManager = StudyActivityManager.shared
        // 同じ教材のアクティビティが表示中ならそのまま更新（一時停止→再開など）、
        // 未表示・別教材なら作り直す
        if !StudyActivityManager.shared.resumeActivity(for: subject, stopwatchManager: self) {
            StudyActivityManager.shared.startActivity(for: subject, stopwatchManager: self)
        }
    }

    
    // 教材設定メソッド
    func setSubject(_ subject: Subject) {
        self.currentSubject = subject
    }
    
    // 内部状態設定メソッド（復元用）
    func setAccumulatedTime(_ time: TimeInterval) {
        self.accumulatedTime = time
    }
    
    func setElapsedTime(_ time: TimeInterval) {
        self.elapsedTime = time
    }
    
    // エラーハンドリング版で状態復元（別教材のセッションを誤って復元しないようsubjectIdを照合）
    func restoreStateIfNeeded(for subjectId: UUID) {
        // StudySessionManagerを優先、エラー時はLiveActivityManagerを使用
        if let activeSession = tryGetStudySession(), activeSession.subjectId == subjectId {
            restoreFromStudySession(activeSession)
        } else if let liveActivityState = LiveActivitySessionManager.shared.getLiveActivityState(), liveActivityState.subjectId == subjectId {
            restoreFromLiveActivity(liveActivityState)
        }
    }
    
    // MARK: - Private Methods

    // Dynamic Islandコンパクト表示のタイマー幅（9:59 / 59:59 / 9:59:59）が
    // 切り替わる境界をまたいだら、Live Activityを再描画して幅を追従させる
    private func refreshActivityOnDisplayBoundary(previous: TimeInterval, current: TimeInterval) {
        let displayBoundaries: [TimeInterval] = [600, 3600]
        if displayBoundaries.contains(where: { previous < $0 && current >= $0 }) {
            activityManager?.updateActivity()
        }
    }

    private func updateElapsedTime() {
        if let startDate = startDate, isRunning {
            elapsedTime = accumulatedTime + Date().timeIntervalSince(startDate)
        } else {
            elapsedTime = accumulatedTime
        }
    }
    
    // エラーハンドリング版で状態保存
    private func saveCurrentState() {
        guard let subject = currentSubject else {
            return
        }
        
        // 学習時間が記録されている場合のみ保存
        if elapsedTime > 0 || isRunning {
            // メインアプリ用の保存
            saveToStudySessionManager(subject: subject)
            
            // Live Activity用の軽量保存
            LiveActivitySessionManager.shared.saveLiveActivityState(
                subjectId: subject.id,
                subjectName: subject.name,
                subjectColor: subject.color.toHex(), // 教材の実際の色
                elapsedTime: elapsedTime,
                isRunning: isRunning
            )
        }
    }
    
    // StudySessionManager保存のエラーハンドリング
    private func saveToStudySessionManager(subject: Subject) {
        StudySessionManager.shared.saveActiveSession(subject: subject, stopwatchManager: self)
    }
    
    // StudySession取得のエラーハンドリング
    private func tryGetStudySession() -> StudySessionState? {
        StudySessionManager.shared.getActiveSession()
    }
    
    // エラーハンドリング版で状態クリア
    private func clearSessionState() {
        StudySessionManager.shared.clearActiveSession()

        // LiveActivityManager のクリア（常に実行）
        LiveActivitySessionManager.shared.clearLiveActivityState()
    }
    
    // 完全な状態復元（エラーハンドリング付き）
    private func restoreFromStudySession(_ sessionState: StudySessionState) {
        self.accumulatedTime = sessionState.accumulatedTime
        
        if sessionState.isRunning {
            let timeSinceLastUpdate = Date().timeIntervalSince(sessionState.lastUpdateTime)
            self.accumulatedTime += timeSinceLastUpdate
            self.isRunning = true
            self.startDate = Date()
            
            // タイマーを再開
            timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
                .autoconnect()
                .map { _ in Date() }
                .sink { [weak self] _ in
                    self?.updateElapsedTime()
                }
        }
        
        updateElapsedTime()
    }
    
    // Live Activity状態復元
    private func restoreFromLiveActivity(_ liveActivityState: LiveActivityState) {
        self.elapsedTime = liveActivityState.elapsedTime
        self.isRunning = liveActivityState.isRunning
        
        if isRunning {
            let timeSinceLastUpdate = Date().timeIntervalSince(liveActivityState.lastUpdateTime)
            self.elapsedTime += timeSinceLastUpdate
            self.startDate = Date()
            
            // 累積時間を現在の経過時間に合わせて設定し、タイマーを開始
            self.accumulatedTime = self.elapsedTime
            timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
                .autoconnect()
                .map { _ in Date() }
                .sink { [weak self] _ in
                    self?.updateElapsedTime()
                }
        }
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
}
