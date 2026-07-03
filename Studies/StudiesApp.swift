//
//  StudiesApp.swift
//  Studies
//

import SwiftUI
import SwiftData

@main
struct StudiesApp: App {
    private let diContainer = DIContainer.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(diContainer)
                .modelContainer(diContainer.modelContainer) // ← DIContainerから取得
        }
    }
    
    // ← 削除: createModelContainer()関数は不要
}
