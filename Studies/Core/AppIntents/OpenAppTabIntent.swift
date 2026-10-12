//
//  OpenAppTabIntent.swift
//  Studies
//

import AppIntents
import Foundation

enum StudiesAppTab: String, AppEnum {
    case record
    case stats
    case goals
    case history

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Tab"

    static var caseDisplayRepresentations: [StudiesAppTab: DisplayRepresentation] = [
        .record: "Record",
        .stats: "Statistics",
        .goals: "Goals",
        .history: "History"
    ]
}

struct OpenAppTabIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Studies Tab"
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Tab", default: .stats)
    var tab: StudiesAppTab

    func perform() async throws -> some IntentResult {
        return .result(opensIntent: OpenURLIntent(URL(string: "studies://tab/\(tab.rawValue)")!))
    }
}
