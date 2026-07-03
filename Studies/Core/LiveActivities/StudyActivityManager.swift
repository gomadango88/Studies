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
    // 開始処理（全クリア→新規作成）の実行中タスク。
    // endActivityがこれを待ってから終了することで、作成直後の取り残しを防ぐ
    private var startTask: Task<Void, Never>?

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
    }

    /// Live Activityを開始
    func startActivity(for subject: Subject, stopwatchManager: StopwatchProtocol) {
        print("StudyActivityManager startActivity for subject: \(subject.name)")
        startTask?.cancel()
        startTask = Task {
            //既存のアクティビティをすべてクリア
            await clearAllActivitiesOnAppLaunch()
            // クリア中に保存・リセットと競合した場合は新規作成しない（取り残し防止）
            guard !Task.isCancelled else { return }
            // 新しいActivityを作成
            await createNewActivity(for: subject, stopwatchManager: stopwatchManager)
        }
    }

    /// 表示中のアクティビティが同じ教材のものなら、ストップウォッチの参照を
    /// 差し替えて更新する。未表示・別教材ならfalseを返し、呼び出し側で作り直す
    func resumeActivity(for subject: Subject, stopwatchManager: StopwatchProtocol) -> Bool {
        guard let activity = currentActivity,
              activity.attributes.subjectId == subject.id else {
            return false
        }
        self.stopwatchManager = stopwatchManager
        updateActivity()
        return true
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
            subjectId: subject.id,
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
        // 開始処理が実行中なら中断を要求し、完了を待ってから終了する。
        // これを待たないと、終了後に開始処理が新しいアクティビティを作って取り残される
        startTask?.cancel()
        await startTask?.value
        startTask = nil

        if let activity = currentActivity {
            await activity.end(nil, dismissalPolicy: .immediate)
            print("Live Activity ended")
        }

        // 参照が切れたまま残っているアクティビティも確実に掃除する
        for activity in Activity<StudyActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
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
