//
//  OpenSubjectIntent.swift
//  Studies
//

import AppIntents
import Foundation

@AppIntent(schema: .system.open)
struct OpenSubjectIntent: OpenIntent {
    static var title: LocalizedStringResource = "Open Subject"
    static var description = IntentDescription("Opens the study session screen for the chosen subject in Studies.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Subject")
    var target: SubjectEntity

    func perform() async throws -> some IntentResult {
        return .result(opensIntent: OpenURLIntent(URL(string: "studies://subject/\(target.id.uuidString)")!))
    }
}
