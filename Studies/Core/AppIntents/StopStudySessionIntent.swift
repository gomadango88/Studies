//
//  StopStudySessionIntent.swift
//  Studies
//

import AppIntents
import Foundation
import os

struct StopStudySessionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop Studying"

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let session = StudySessionManager.shared.getActiveSession() else {
            return .result(dialog: "No study session is currently running.")
        }

        let duration = session.accumulatedTime + (session.isRunning ? max(0, Date().timeIntervalSince(session.lastUpdateTime)) : 0)

        guard duration > 0 else {
            await StudyActivityManager.shared.endActivity()
            StudySessionManager.shared.clearActiveSession()
            LiveActivitySessionManager.shared.clearLiveActivityState()
            return .result(dialog: "There was no study time to record.")
        }

        do {
            _ = try await DIContainer.shared.studyRecordUseCase.createRecord(
                subjectId: session.subjectId,
                duration: duration,
                studyDate: Date()
            )
        } catch {
            // 記録に失敗した場合はセッション状態を残し、次回のリトライで学習時間が失われないようにする
            let message = (error as? StudyRecordUseCaseError)?.errorDescription ?? error.localizedDescription
            Logger.intents.error("Failed to save study record from intent: \(error)")
            return .result(dialog: "Couldn't save your study record: \(message)")
        }

        await StudyActivityManager.shared.endActivity()
        StudySessionManager.shared.clearActiveSession()
        LiveActivitySessionManager.shared.clearLiveActivityState()
        await WidgetUpdateService.update(using: DIContainer.shared)

        let formattedDuration = Self.formattedDuration(duration)
        let subjects = try? await DIContainer.shared.subjectUseCase.getAllSubjects()
        guard let subjectName = subjects?.first(where: { $0.id == session.subjectId })?.name else {
            return .result(dialog: "Logged \(formattedDuration) of study time.")
        }

        return .result(dialog: "Logged \(formattedDuration) for “\(subjectName)”.")
    }

    private static func formattedDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = duration < 60 ? [.minute, .second] : [.hour, .minute]
        return formatter.string(from: duration) ?? ""
    }
}
