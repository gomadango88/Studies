//
//  StopwatchManager.swift
//  Studies
//
//  Created by takuma on 2025/08/08.
//

import Foundation
import SwiftUI

@MainActor
@Observable
class StopwatchManager: StopwatchProtocol {
    private(set) var isRunning = false
    private(set) var elapsedTime: TimeInterval = 0
    
    private var startTime: Date?
    private var accumulatedTime: TimeInterval = 0
    
    // Timer を nonisolated として管理（actor isolation回避）
    private let displayTimer: ManagedTimer = ManagedTimer()
    
    // MARK: - Public Methods
    
    func start() {
        guard !isRunning else { return }
        
        // 触覚フィードバック
        HapticFeedback.rigid()
        
        isRunning = true
        startTime = Date()
        
        displayTimer.start(interval: 0.1) { [weak self] in
            Task { @MainActor [weak self] in
                await self?.updateDisplay()
            }
        }
    }

    // Live Activity統合用のメソッド
    func startWithLiveActivity(for subject: Subject) {
        start()  // 通常のストップウォッチ開始
        
        // Live Activity開始
        Task { @MainActor in
            StudyActivityManager.shared.startActivity(for: subject, stopwatchManager: self)
        }
    }
    
    func stop() {
        guard isRunning else { return }
        
        HapticFeedback.rigid()
        
        // 経過時間を累積
        if let startTime = startTime {
            accumulatedTime += Date().timeIntervalSince(startTime)
        }
        
        isRunning = false
        startTime = nil
        
        // Timer を停止
        displayTimer.stop()
        
        // 最終表示を更新
        elapsedTime = accumulatedTime
        
        // Live Activity更新
        StudyActivityManager.shared.updateActivity()
    }
    
    func reset() {
        HapticFeedback.rigid()
        
        isRunning = false
        startTime = nil
        accumulatedTime = 0
        elapsedTime = 0
        
        // Timer を停止
        displayTimer.stop()
        
        // Live Activity終了（修正）
        StudyActivityManager.shared.handleReset()
    }

    
    func toggle() {
        if isRunning {
            stop()
        } else {
            start()
        }
    }
    
    // MARK: - Private Methods
    
    private func updateDisplay() async {
        guard isRunning, let startTime = startTime else { return }
        elapsedTime = accumulatedTime + Date().timeIntervalSince(startTime)
    }
    
    // MARK: - Computed Properties
    
    var formattedTime: String {
        formatTimeInterval(elapsedTime)
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

// MARK: - ManagedTimer Helper Class

private final class ManagedTimer {
    private var timer: Timer?
    
    func start(interval: TimeInterval, handler: @escaping () -> Void) {
        stop() // 既存のTimerを停止
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            handler()
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    deinit {
        stop()
    }
}
