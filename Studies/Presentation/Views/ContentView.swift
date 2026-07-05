//
// ContentView.swift
// Studies
//
// Created by takuma on 2025/08/08.
//

import SwiftUI
import SwiftData
import os

struct ContentView: View {
    @Environment(DIContainer.self) private var diContainer

    @State private var shouldShowActiveSession = false
    @State private var activeSubject: Subject?
    @State private var showingSessionRestoreAlert = false

    // 永続ストア初期化失敗時の警告アラート用の状態（起動後1回だけ表示）
    @State private var showingPersistentStoreUnavailableAlert = false

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    enum AppTab: Hashable { case record, stats, goals, history }
    
    @State private var selectedTab: AppTab = .record
    
    var body: some View {
        
        TabView(selection: $selectedTab) {
            Tab("記録", systemImage: "stopwatch", value: AppTab.record) {
                StudyRecordMainView()
            }

            Tab("統計", systemImage: "chart.bar", value: AppTab.stats) {
                StatisticsView()
            }

            Tab("目標", systemImage: "flag.fill", value: AppTab.goals) {
                GoalSettingView()
            }

            Tab("履歴", systemImage: "clock.arrow.circlepath", value: AppTab.history) {
                TimelineView()
            }
        }
        .onAppear {
            Task { await WidgetUpdateService.update(using: diContainer) }

            // オンボーディング未完了時はシートとの競合を避けるため、完了後にまとめて実行する
            if hasCompletedOnboarding {
                StudiesTipsState.hasCompletedOnboarding = true
                runPostLaunchChecks()
            }
        }
        .sheet(isPresented: Binding(get: { !hasCompletedOnboarding }, set: { _ in })) {
            OnboardingView {
                hasCompletedOnboarding = true
                StudiesTipsState.hasCompletedOnboarding = true
                runPostLaunchChecks()
            }
            .interactiveDismissDisabled()
        }
        .sheet(isPresented: $shouldShowActiveSession) {
            if let subject = activeSubject {
                StudySessionView(subject: subject)
                    .onAppear {
                        
                    }
                    .onDisappear {
                        activeSubject = nil
                        shouldShowActiveSession = false
                    }
            }
        }
        .alert("学習セッションが見つかりました", isPresented: $showingSessionRestoreAlert) {
            Button("学習を継続") {
                
                shouldShowActiveSession = true
                showingSessionRestoreAlert = false
            }
            
            Button("セッションを破棄", role: .cancel) {

                StudySessionManager.shared.clearActiveSession()
                LiveActivitySessionManager.shared.clearLiveActivityState()
                Task {
                    await StudyActivityManager.shared.clearAllActivitiesOnAppLaunch()
                }
                activeSubject = nil
                showingSessionRestoreAlert = false
            }
        } message: {
            if let subject = activeSubject {
                Text("「\(subject.name)」の学習を継続しますか？\nストップウォッチのカウントは保存されています。")
            } else {
                Text("前回の学習セッションを継続しますか？")
            }
        }
        .alert("データを保存できません", isPresented: $showingPersistentStoreUnavailableAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("学習データの保存領域を初期化できなかったため、記録は端末を再起動するまで一時的にのみ保持されます。問題が続く場合は、空き容量を確認するかアプリを再インストールしてください。")
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
    }

    private func handleDeepLink(_ url: URL) {

        guard url.scheme == "studies" else {
            Logger.ui.warning("Unknown URL scheme: \(url.scheme ?? "nil")")
            return
        }
        
        if url.host == "studygoal" {
            
            withAnimation(.easeInOut(duration: 0.3)) { selectedTab = .goals }
            return
        }
        
        // New format: studies://tab/<name>
        if url.host == "tab" {
            let tabName = url.pathComponents.dropFirst().first // first component after '/'
            switch tabName {
            case "record":
                withAnimation(.easeInOut(duration: 0.3)) { selectedTab = .record }
            case "stats":
                withAnimation(.easeInOut(duration: 0.3)) { selectedTab = .stats }
            case "goals":
                withAnimation(.easeInOut(duration: 0.3)) { selectedTab = .goals }
            case "history":
                withAnimation(.easeInOut(duration: 0.3)) { selectedTab = .history }
            default:
                Logger.ui.warning("Unknown tab name: \(tabName ?? "nil")")
            }
            return
        }

        Logger.ui.warning("Unknown deep link host: \(url.host ?? "nil")")
    }
    
    private func runPostLaunchChecks() {
        checkForActiveStudySession()

        // 永続ストアの初期化に失敗し、インメモリストアで動作している場合は
        // 起動後1回だけユーザーに注意喚起する
        if diContainer.isPersistentStoreUnavailable {
            showingPersistentStoreUnavailableAlert = true
        }
    }

    private func checkForActiveStudySession() {
        
        guard let activeSession = StudySessionManager.shared.getActiveSession() else {
            
            return
        }
        
        
        Task {
            do {
                let subjects = try await diContainer.subjectUseCase.getAllSubjects()
                if let subject = subjects.first(where: { $0.id == activeSession.subjectId }) {
                    
                    await MainActor.run {
                        self.activeSubject = subject
                        self.showingSessionRestoreAlert = true
                    }
                } else {
                    Logger.session.warning("Subject not found, clearing active session")
                    StudySessionManager.shared.clearActiveSession()
                }
            } catch {
                Logger.session.error("Error loading subjects: \(error)")
                StudySessionManager.shared.clearActiveSession()
            }
        }
    }
}

struct StudyRecordMainView: View {
    var body: some View {
        
        SubjectListView()
    }
}

#Preview {
    ContentView()
        .environment(DIContainer.shared)
}
