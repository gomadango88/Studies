//
//  StudiesAppShortcuts.swift
//  Studies
//

import AppIntents

struct StudiesAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartStudySessionIntent(),
            phrases: [
                "Start studying in \(.applicationName)",
                "Start studying \(\.$subject) in \(.applicationName)",
                "Start a \(.applicationName) session"
            ],
            shortTitle: "Start Studying",
            systemImageName: "stopwatch"
        )

        AppShortcut(
            intent: StopStudySessionIntent(),
            phrases: [
                "Stop studying in \(.applicationName)",
                "Stop my \(.applicationName) session",
                "End studying in \(.applicationName)"
            ],
            shortTitle: "Stop Studying",
            systemImageName: "stop.circle"
        )

        AppShortcut(
            intent: LogStudyRecordIntent(),
            phrases: [
                "Log study time in \(.applicationName)",
                "Log a study session in \(.applicationName)",
                "Record study time with \(.applicationName)"
            ],
            shortTitle: "Log Study Time",
            systemImageName: "square.and.pencil"
        )

        AppShortcut(
            intent: GetTodayStudyTimeIntent(),
            phrases: [
                "How long did I study today in \(.applicationName)",
                "Show my \(.applicationName) study time",
                "What's my study time in \(.applicationName)"
            ],
            shortTitle: "Today's Study Time",
            systemImageName: "chart.bar"
        )

        AppShortcut(
            intent: OpenAppTabIntent(),
            phrases: [
                "Open \(\.$tab) in \(.applicationName)",
                "Show \(\.$tab) in \(.applicationName)"
            ],
            shortTitle: "Open Tab",
            systemImageName: "arrow.up.forward.app"
        )
    }
}
