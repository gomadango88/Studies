//
//  StudiesApp.swift
//  Studies
//

import SwiftUI
import SwiftData
import TipKit

@main
struct StudiesApp: App {
    private let diContainer = DIContainer.shared

    init() {
        #if DEBUG
        // resetDatastore() と showAllTipsForTesting() は configure() より前に呼ぶ必要がある
        if CommandLine.arguments.contains("--reset-onboarding") {
            UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
            try? Tips.resetDatastore()
        }
        if CommandLine.arguments.contains("--show-all-tips") {
            Tips.showAllTipsForTesting()
        }
        #endif

        try? Tips.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(diContainer)
                .modelContainer(diContainer.modelContainer) // ← DIContainerから取得
        }
    }

    // ← 削除: createModelContainer()関数は不要
}
