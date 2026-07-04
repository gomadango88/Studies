//
// StudyActivityManager.swift
// Studies
//
// Created by takuma on 2025/08/08.
//

import Foundation
import ActivityKit
import SwiftUI
import os


private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Studies", category: "liveActivity")

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
    
    func clearAllActivitiesOnAppLaunch() async {
        if let currentActivity = currentActivity {
            await currentActivity.end(nil, dismissalPolicy: .immediate)
            self.currentActivity = nil
        }

        let activities = Activity<StudyActivityAttributes>.activities
        for activity in activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    func startActivity(for subject: Subject, stopwatchManager: StopwatchProtocol) {
        startTask?.cancel()
        startTask = Task {
            await clearAllActivitiesOnAppLaunch()
            // クリア中に保存・リセットと競合した場合は新規作成しない（取り残し防止）
            guard !Task.isCancelled else { return }
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
    
    private func createNewActivity(for subject: Subject, stopwatchManager: StopwatchProtocol) async {
        self.stopwatchManager = stopwatchManager
        guard let stopwatch = self.stopwatchManager else {
            logger.warning("stopwatchManager is nil, cannot create Live Activity")
            return
        }

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
        } catch {
            logger.error("Live Activity start error: \(error)")
        }
    }

    /// Live Activityを更新（開始・一時停止・再開・保存などイベント発生時にのみ呼び出す）
    func updateActivity() {
        guard let activity = currentActivity,
              let stopwatch = stopwatchManager else {
            return
        }

        Task {
            let contentState = makeContentState(from: stopwatch)
            await activity.update(.init(state: contentState, staleDate: nil))
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


    func endActivity() async {
        // 開始処理が実行中なら中断を要求し、完了を待ってから終了する。
        // これを待たないと、終了後に開始処理が新しいアクティビティを作って取り残される
        startTask?.cancel()
        await startTask?.value
        startTask = nil

        if let activity = currentActivity {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        // 参照が切れたまま残っているアクティビティも確実に掃除する
        for activity in Activity<StudyActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        currentActivity = nil
        stopwatchManager = nil
    }

    func endActivity() {
        Task {
            await endActivity()
        }
    }

    // MARK: - Reset Handling

    func handleReset() {
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
