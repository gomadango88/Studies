//
// StudyActivityManager.swift
// Studies
//
// Created by takuma on 2025/08/08.
//

import Foundation
import ActivityKit
import SwiftUI

@MainActor
@Observable
class StudyActivityManager {
    static let shared = StudyActivityManager()
    
    private var currentActivity: Activity<StudyActivityAttributes>?
    private weak var stopwatchManager: StopwatchProtocol?
    var todayTotalTimeProvider: (() async -> String)?
    
    private init() {
        print("🏗️ StudyActivityManager init")
    }
    
    // MARK: - Activity Management
    
    ///アプリ起動時全ライブアクティビティクリア
    func clearAllActivitiesOnAppLaunch() async {
        print("🧹 Clearing all Live Activities on app launch")
        // 現在のアクティビティを終了
        if let currentActivity = currentActivity {
            print("🛑 Ending current activity")
            await currentActivity.end(nil, dismissalPolicy: .immediate)
            self.currentActivity = nil
        }
        
        // すべてのアクティブなアクティビティを取得して終了
        let activities = Activity<StudyActivityAttributes>.activities
        print("📊 Found \(activities.count) active activities to clear")
        for activity in activities {
            print("🛑 Ending activity: \(activity.id)")
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        
        // タイマー停止
        stopPeriodicUpdates()
        print("✅ All Live Activities cleared")
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
        print("🧹 Live Activity cleanup completed")
    }
    
    /// Live Activityを開始
    func startActivity(for subject: Subject, stopwatchManager: StopwatchProtocol) {
        print("🚀 StudyActivityManager startActivity for subject: \(subject.name)")
        Task {
            //既存のアクティビティをすべてクリア
            await clearAllActivitiesOnAppLaunch()
            // 新しいActivityを作成
            await createNewActivity(for: subject, stopwatchManager: stopwatchManager)
        }
    }
    
    /// 新しいActivity作成
    private func createNewActivity(for subject: Subject, stopwatchManager: StopwatchProtocol) async {
        self.stopwatchManager = stopwatchManager
        guard let stopwatch = self.stopwatchManager else {
            print("❌ stopwatchManager is nil")
            return
        }
        
        print("📊 Creating new Live Activity - elapsed: \(stopwatch.elapsedTime), running: \(stopwatch.isRunning)")
        
        let attributes = StudyActivityAttributes(
            subjectName: subject.name,
            subjectColor: subject.color.toHex(),
            startTime: Date()
        )
        
        let todayTotal = await getTodayTotalTime()
        
        let contentState = StudyActivityAttributes.ContentState(
            elapsedTime: stopwatch.elapsedTime,
            isRunning: stopwatch.isRunning,
            lastUpdateTime: Date(),
            todayTotalTime: todayTotal
        )
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: Date().addingTimeInterval(60))
            )
            
            currentActivity = activity
            print("✅ 新しいLive Activity開始成功")
            startPeriodicUpdates()
        } catch {
            print("❌ Live Activity開始エラー: \(error)")
        }
    }
    
    /// Live Activityを更新
    func updateActivity() {
        guard let activity = currentActivity,
              let stopwatch = stopwatchManager else {
            print("⚠️ updateActivity: activity or stopwatch is nil")
            return
        }
        
        print("🔄 Updating Live Activity - elapsed: \(stopwatch.elapsedTime), running: \(stopwatch.isRunning)")
        
        Task {
            let todayTotal = await getTodayTotalTime()
            
            let contentState = StudyActivityAttributes.ContentState(
                elapsedTime: stopwatch.elapsedTime,
                isRunning: stopwatch.isRunning,
                lastUpdateTime: Date(),
                todayTotalTime: todayTotal
            )
            
            do {
                await activity.update(.init(state: contentState, staleDate: Date().addingTimeInterval(60)))
                print("✅ Live Activity updated successfully")
            } catch {
                print("❌ Live Activity更新エラー: \(error)")
            }
        }
    }
    
    private func getTodayTotalTime() async -> String {
        print("📊 Getting today total time...")
        if let provider = todayTotalTimeProvider {
            let result = await provider()
            print("📊 Today total from provider: \(result)")
            return result
        } else {
            print("⚠️ todayTotalTimeProvider is nil, returning default")
            return "0:00"
        }
    }

    
    /// Live Activityを終了
    func endActivity() async {
        print("🔴 StudyActivityManager endActivity called")
        stopPeriodicUpdates()
        if let activity = currentActivity {
            await activity.end(nil, dismissalPolicy: .immediate)
            print("✅ Live Activity ended")
        }
        
        currentActivity = nil
        stopwatchManager = nil
        print("🔴 Live Activity終了完了")
    }
    
    func endActivity() {
        Task {
            await endActivity()
        }
    }
    
    // MARK: - Intent Actions
    
    /// 学習を再開
    func resumeStudy() async {
        guard let stopwatch = stopwatchManager else {
            print("❌ resumeStudy: stopwatch is nil")
            return
        }
        
        print("▶️ Resuming study")
        stopwatch.start()
        updateActivity()
        NotificationCenter.default.post(name: .liveActivityResumed, object: nil)
    }
    
    /// 学習を停止
    func stopStudy() async {
        guard let stopwatch = stopwatchManager else {
            print("❌ stopStudy: stopwatch is nil")
            return
        }
        
        print("⏸️ Stopping study")
        stopwatch.stop()
        updateActivity()
        NotificationCenter.default.post(name: .liveActivityStopped, object: nil)
    }
    
    
    // MARK: - Periodic Updates
    
    private var updateTimer: Timer?
    
    private func startPeriodicUpdates() {
        print("⏰ Starting periodic updates")
        if updateTimer != nil {
            print("⏰ Stopping existing timer before starting new one")
            stopPeriodicUpdates()
        }
        
        // 10秒間隔で更新
        updateTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                print("⚠️ self is nil in updateTimer callback - invalidating timer")
                timer.invalidate()
                return
            }
            
            print("⏰ Timer tick (10s interval) - updating Live Activity")
            Task { @MainActor in
                self.updateActivity()
            }
        }
        updateTimer?.tolerance = 1.0
        print("⏰ Timer scheduled with 10.0 second interval")
    }
    
    nonisolated private func stopPeriodicUpdates() {
        print("⏰ Stopping periodic updates")
        Task { @MainActor in
            if let timer = self.updateTimer {
                timer.invalidate()
                print("⏰ Timer invalidated")
            } else {
                print("⏰ No timer to stop")
            }
            
            self.updateTimer = nil
            print("⏰ Timer set to nil")
        }
    }
    
    deinit {
        print("💀 StudyActivityManager deinit")
        stopPeriodicUpdates()
    }
    
    // MARK: - Reset Handling
    
    /// リセット時の処理
    func handleReset() {
        print("🔄 StudyActivityManager handleReset")
        Task {
            await endActivity()
        }
    }
    
    // MARK: - Computed Properties
    
    var isActivityActive: Bool {
        let active = currentActivity != nil
        print("📊 isActivityActive: \(active)")
        return active
    }
}

// MARK: - Color Extension
extension Color {
    func toHex() -> String {
        guard let components = UIColor(self).cgColor.components else {
            return "#000000"
        }
        
        let red = Int(components[0] * 255.0)
        let green = Int(components[1] * 255.0)
        let blue = Int(components[2] * 255.0)
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let liveActivityResumed = Notification.Name("liveActivityResumed")
    static let liveActivityStopped = Notification.Name("liveActivityStopped")
}
