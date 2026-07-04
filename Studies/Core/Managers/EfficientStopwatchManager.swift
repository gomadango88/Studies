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
    private weak var activityManager: StudyActivityManager?
    private var currentSubject: Subject?
    
    // MARK: - Public Methods
    
    func start() {
        guard !isRunning else {
            return
        }
        
        HapticFeedback.rigid()
        startDate = Date()
        isRunning = true
        
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
        timerCancellable?.cancel()
        timerCancellable = nil

        updateElapsedTime()

        activityManager?.updateActivity()

        saveCurrentState()
    }

    func reset() {
        HapticFeedback.rigid()

        timerCancellable?.cancel()
        timerCancellable = nil

        isRunning = false
        startDate = nil
        accumulatedTime = 0
        elapsedTime = 0

        activityManager?.handleReset()

        clearSessionState()
    }

    func startWithLiveActivity(for subject: Subject) {
        setSubject(subject)

        start()

        activityManager = StudyActivityManager.shared
        // 同じ教材のアクティビティが表示中ならそのまま更新（一時停止→再開など）、
        // 未表示・別教材なら作り直す
        if !StudyActivityManager.shared.resumeActivity(for: subject, stopwatchManager: self) {
            StudyActivityManager.shared.startActivity(for: subject, stopwatchManager: self)
        }
    }

    func setSubject(_ subject: Subject) {
        self.currentSubject = subject
    }

    func setAccumulatedTime(_ time: TimeInterval) {
        self.accumulatedTime = time
    }

    func setElapsedTime(_ time: TimeInterval) {
        self.elapsedTime = time
    }

    // 別教材のセッションを誤って復元しないようsubjectIdを照合する
    func restoreStateIfNeeded(for subjectId: UUID) {
        // StudySessionManagerを優先、エラー時はLiveActivityManagerを使用
        if let activeSession = tryGetStudySession(), activeSession.subjectId == subjectId {
            restoreFromStudySession(activeSession)
        } else if let liveActivityState = LiveActivitySessionManager.shared.getLiveActivityState(), liveActivityState.subjectId == subjectId {
            restoreFromLiveActivity(liveActivityState)
        }
    }
    
    // MARK: - Private Methods

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

    private func saveCurrentState() {
        guard let subject = currentSubject else {
            return
        }

        if elapsedTime > 0 || isRunning {
            saveToStudySessionManager(subject: subject)

            LiveActivitySessionManager.shared.saveLiveActivityState(
                subjectId: subject.id,
                subjectName: subject.name,
                subjectColor: subject.color.toHex(),
                elapsedTime: elapsedTime,
                isRunning: isRunning
            )
        }
    }

    private func saveToStudySessionManager(subject: Subject) {
        StudySessionManager.shared.saveActiveSession(subject: subject, stopwatchManager: self)
    }

    private func tryGetStudySession() -> StudySessionState? {
        StudySessionManager.shared.getActiveSession()
    }

    private func clearSessionState() {
        StudySessionManager.shared.clearActiveSession()
        LiveActivitySessionManager.shared.clearLiveActivityState()
    }

    private func restoreFromStudySession(_ sessionState: StudySessionState) {
        self.accumulatedTime = sessionState.accumulatedTime
        
        if sessionState.isRunning {
            let timeSinceLastUpdate = Date().timeIntervalSince(sessionState.lastUpdateTime)
            self.accumulatedTime += timeSinceLastUpdate
            self.isRunning = true
            self.startDate = Date()

            timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
                .autoconnect()
                .map { _ in Date() }
                .sink { [weak self] _ in
                    self?.updateElapsedTime()
                }
        }

        updateElapsedTime()
    }

    private func restoreFromLiveActivity(_ liveActivityState: LiveActivityState) {
        self.elapsedTime = liveActivityState.elapsedTime
        self.isRunning = liveActivityState.isRunning
        
        if isRunning {
            let timeSinceLastUpdate = Date().timeIntervalSince(liveActivityState.lastUpdateTime)
            self.elapsedTime += timeSinceLastUpdate
            self.startDate = Date()

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
