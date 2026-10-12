//
//  LogStudyRecordIntent.swift
//  Studies
//

import AppIntents
import Foundation
import os

struct LogStudyRecordIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Study Time"

    @Parameter(title: "Subject")
    var subject: SubjectEntity

    @Parameter(title: "Duration")
    var duration: Measurement<UnitDuration>

    @Parameter(title: "Date")
    var date: Date?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let seconds = duration.converted(to: .seconds).value

        guard seconds > 0 else {
            return .result(dialog: "Please enter a duration greater than zero.")
        }

        guard seconds <= 24 * 3600 else {
            return .result(dialog: "Please enter a duration within 24 hours.")
        }

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

        do {
            _ = try await DIContainer.shared.studyRecordUseCase.createRecord(
                subjectId: resolvedSubject.id,
                duration: seconds,
                studyDate: date ?? Date()
            )
        } catch {
            let message = (error as? StudyRecordUseCaseError)?.errorDescription ?? error.localizedDescription
            Logger.intents.error("Failed to save study record from intent: \(error)")
            return .result(dialog: "Couldn't save your study record: \(message)")
        }

        await WidgetUpdateService.update(using: DIContainer.shared)

        let formattedDuration = Self.formattedDuration(seconds)
        return .result(dialog: "Logged \(formattedDuration) for “\(resolvedSubject.name)”.")
    }

    private static func formattedDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = duration < 60 ? [.minute, .second] : [.hour, .minute]
        return formatter.string(from: duration) ?? ""
    }
}
