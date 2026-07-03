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

    private init() {
    }
    
    // MARK: - Activity Management
    
    ///アプリ起動時全ライブアクティビティクリア
    func clearAllActivitiesOnAppLaunch() async {
        print("Clearing all Live Activities on app launch")
        // 現在のアクティビティを終了
        if let currentActivity = currentActivity {
            print("Ending current activity")
            await currentActivity.end(nil, dismissalPolicy: .immediate)
            self.currentActivity = nil
        }
        
        // すべてのアクティブなアクティビティを取得して終了
        let activities = Activity<StudyActivityAttributes>.activities
        print("Found \(activities.count) active activities to clear")
        for activity in activities {
            print("Ending activity: \(activity.id)")
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        print("All Live Activities cleared")
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
        print("Live Activity cleanup completed")
    }
    
    /// Live Activityを開始
    func startActivity(for subject: Subject, stopwatchManager: StopwatchProtocol) {
        print("StudyActivityManager startActivity for subject: \(subject.name)")
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
            print("stopwatchManager is nil")
            return
        }

        print("Creating new Live Activity - elapsed: \(stopwatch.elapsedTime), running: \(stopwatch.isRunning)")

        let attributes = StudyActivityAttributes(
            subjectName: subject.name,
            subjectColor: subject.color.toHex(),
            startTime: Date()
        )

        let contentState = makeContentState(from: stopwatch)

        do {
            // Text(timerInterval:)でOSが自動更新するため、定期的な再pushは不要（staleDateも設定しない）
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: nil)
            )

            currentActivity = activity
            print("Live Activity started")
        } catch {
            print("Live Activity start error: \(error)")
        }
    }

    /// Live Activityを更新（開始・一時停止・再開・保存などイベント発生時にのみ呼び出す）
    func updateActivity() {
        guard let activity = currentActivity,
              let stopwatch = stopwatchManager else {
            print("updateActivity: activity or stopwatch is nil")
            return
        }

        print("Updating Live Activity - elapsed: \(stopwatch.elapsedTime), running: \(stopwatch.isRunning)")

        Task {
            let contentState = makeContentState(from: stopwatch)
            await activity.update(.init(state: contentState, staleDate: nil))
            print("Live Activity updated successfully")
        }
    }

    // 実行中はstartDateからの経過、一時停止中はpausedDate時点で固定した経過をLive Activity側で表示する
    private func makeContentState(from stopwatch: StopwatchProtocol) -> StudyActivityAttributes.ContentState {
        let now = Date()
        let adjustedStart = now.addingTimeInterval(-stopwatch.elapsedTime)
        return StudyActivityAttributes.ContentState(
            startDate: adjustedStart,
            pausedDate: stopwatch.isRunning ? nil : now,
            isRunning: stopwatch.isRunning
        )
    }


    /// Live Activityを終了
    func endActivity() async {
        print("StudyActivityManager endActivity called")
        if let activity = currentActivity {
            await activity.end(nil, dismissalPolicy: .immediate)
            print("Live Activity ended")
        }

        currentActivity = nil
        stopwatchManager = nil
        print("Live Activity end completed")
    }

    func endActivity() {
        Task {
            await endActivity()
        }
    }

    // MARK: - Reset Handling
    
    /// リセット時の処理
    func handleReset() {
        print("StudyActivityManager handleReset")
        Task {
            await endActivity()
        }
    }
    
    // MARK: - Computed Properties
    
    var isActivityActive: Bool {
        let active = currentActivity != nil
        print("isActivityActive: \(active)")
        return active
    }
}

// MARK: - Color Extension
extension Color {
    func toHex() -> String {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        return String(
            format: "#%02X%02X%02X",
            Int(red * 255.0),
            Int(green * 255.0),
            Int(blue * 255.0)
        )
    }
}
