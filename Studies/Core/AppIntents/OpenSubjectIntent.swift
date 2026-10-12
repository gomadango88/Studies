//
//  OpenSubjectIntent.swift
//  Studies
//

import AppIntents
import Foundation

struct OpenSubjectIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Subject"
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Subject")
    var subject: SubjectEntity

    func perform() async throws -> some IntentResult {
        return .result(opensIntent: OpenURLIntent(URL(string: "studies://subject/\(subject.id.uuidString)")!))
    }
}
