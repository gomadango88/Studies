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
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    print("📱 App will resign active - saving current state")
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    print("📱 App did become active")
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                    print("📱 App will terminate")
                }
        }
    }
    
    // ← 削除: createModelContainer()関数は不要
}
