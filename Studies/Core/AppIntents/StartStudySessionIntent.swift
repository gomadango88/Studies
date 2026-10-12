//
//  StartStudySessionIntent.swift
//  Studies
//

import AppIntents
import Foundation
import os

// LiveActivityIntentに準拠することで、Live Activityの開始をバックグラウンド(Siri/ショートカット経由)から許可する
struct StartStudySessionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Start Studying"

    @Parameter(title: "Subject")
    var subject: SubjectEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Start studying \(\.$subject)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let subjects: [Subject]
        do {
            subjects = try await DIContainer.shared.subjectUseCase.getAllSubjects()
        } catch {
            Logger.intents.error("Failed to load subjects: \(error)")
            return .result(dialog: "Couldn't load your subjects. Please try again.")
        }

        guard let resolvedSubject = subjects.first(where: { $0.id == subject.id }) else {
            return .result(dialog: "That subject couldn't be found.")
        }

        // 既存セッションを勝手に破棄しない。実行中・別教材の一時停止中は何もせず状況を伝えるのみ
        if let activeSession = StudySessionManager.shared.getActiveSession() {
            if activeSession.isRunning {
                return .result(dialog: "A study session is already running.")
            }

            guard activeSession.subjectId == resolvedSubject.id else {
                return .result(dialog: "You have a paused session for “\(activeSession.subjectName)”. Please check the app.")
            }

            let stopwatchManager = EfficientStopwatchManager()
            stopwatchManager.setSubject(resolvedSubject)
            stopwatchManager.restoreStateIfNeeded(for: resolvedSubject.id)
            stopwatchManager.startWithLiveActivity(for: resolvedSubject)
            return .result(dialog: "Resumed studying “\(resolvedSubject.name)”.")
        }

        let stopwatchManager = EfficientStopwatchManager()
        stopwatchManager.startWithLiveActivity(for: resolvedSubject)
        return .result(dialog: "Started studying “\(resolvedSubject.name)”.")
    }
}
