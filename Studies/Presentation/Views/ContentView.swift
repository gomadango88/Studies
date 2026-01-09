//
// ContentView.swift
// Studies
//
// Created by takuma on 2025/08/08.
//

import SwiftUI
import SwiftData
import WidgetKit // 🔥 追加: ウィジェット更新用

struct ContentView: View {
    @Environment(DIContainer.self) private var diContainer
    
    
    // セッション復元用の状態
    @State private var shouldShowActiveSession = false
    @State private var activeSubject: Subject?
    @State private var showingSessionRestoreAlert = false
    
    // 🔥 追加: タブ選択状態管理
    @State private var selectedTab = 0
    
    var body: some View {
        let _ = print("🏠 ContentView body called - DIContainer exists: \(diContainer != nil)")
        
        TabView(selection: $selectedTab) {
                    // 学習記録画面（メイン画面）
                    Tab("記録", systemImage: "stopwatch", value: 0) {
                        StudyRecordMainView()
                    }
                    
                    // 統計画面
                    Tab("統計", systemImage: "chart.bar", value: 1) {
                        StatisticsView()
                    }
                    
                    
                    
                    // 目標画面
                    Tab("目標", systemImage: "flag.fill", value: 2) {
                        GoalSettingPreview()
                    }
                    
                    // タイムライン画面
                    Tab("履歴", systemImage: "clock.arrow.circlepath", value: 3) {
                        TimelineView()
                    }
                }
        .onAppear {
            print("🏠 ContentView onAppear - DIContainer: \(diContainer)")
            
            
            
            // アクティブセッションのチェック
            checkForActiveStudySession()
            
            // 🔥 追加: アプリ起動時のウィジェット更新
            Task {
                await updateWidgetOnAppLaunch()
            }
        }
        .sheet(isPresented: $shouldShowActiveSession) {
            if let subject = activeSubject {
                StudySessionView(subject: subject)
                    .onAppear {
                        print("🔄 Restored StudySessionView for: \(subject.name)")
                    }
                    .onDisappear {
                        activeSubject = nil
                        shouldShowActiveSession = false
                    }
            }
        }
        .alert("学習セッションが見つかりました", isPresented: $showingSessionRestoreAlert) {
            Button("学習を継続") {
                print("✅ User chose to resume study session")
                shouldShowActiveSession = true
                showingSessionRestoreAlert = false
            }
            
            Button("セッションを破棄", role: .cancel) {
                print("🗑️ User chose to start fresh, clearing active session")
                StudySessionManager.shared.clearActiveSession()
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
        // 🔥 追加: ウィジェットタップ時のURL処理
        .onOpenURL { url in
            print("📱 Received URL: \(url)")
            handleDeepLink(url)
        }
    }
    
    // 🔥 新規追加: ディープリンク処理メソッド
    private func handleDeepLink(_ url: URL) {
        print("🔗 Processing deep link: \(url)")
        
        if url.scheme == "studies" {
            switch url.host {
            case "studygoal":
                print("🎯 Navigating to StudyGoal tab")
                withAnimation(.easeInOut(duration: 0.3)) {
                    selectedTab = 2 // 目標タブに遷移
                }
            default:
                print("⚠️ Unknown deep link host: \(url.host ?? "nil")")
            }
        } else {
            print("⚠️ Unknown URL scheme: \(url.scheme ?? "nil")")
        }
    }
    
    // 🔥 新規追加: アプリ起動時のウィジェット更新メソッド
    private func updateWidgetOnAppLaunch() async {
        print("📱 Updating widget data on app launch...")
        
        do {
            // 全教材の今日の合計時間を計算
            let totalTodayMinutes = await calculateTotalTodayMinutes()
            
            // 実際のスケジュール目標を取得
            let actualDailyGoal = await getActualDailyGoalMinutes()
            
            // 実際の連続日数を取得
            let actualStreakDays = await getActualStreakDays()
            
            let widgetData = WidgetStudyGoalData(
                dailyGoal: actualDailyGoal,
                todayMinutes: totalTodayMinutes,
                streakDays: actualStreakDays,
                lastUpdated: Date()
            )
            
            print("📱 Widget data on app launch: \(widgetData)")
            WidgetDataManager.shared.saveWidgetData(widgetData)
            
            // ウィジェット更新をリクエスト
            WidgetCenter.shared.reloadAllTimelines()
            
            print("✅ Widget updated on app launch - Today: \(totalTodayMinutes)min, Goal: \(actualDailyGoal)min")
            
        } catch {
            print("❌ Error updating widget on app launch: \(error)")
        }
    }
    
    // 🔥 全教材の今日の合計時間を計算
    private func calculateTotalTodayMinutes() async -> Int {
        do {
            let today = Calendar.current.startOfDay(for: Date())
            let allRecords = try await diContainer.studyRecordUseCase.getRecordsForDate(today)
            
            let totalSeconds = allRecords.reduce(0) { $0 + $1.duration }
            let totalMinutes = Int(totalSeconds / 60)
            
            print("✅ App launch - total today minutes: \(totalMinutes) from \(allRecords.count) records")
            return totalMinutes
            
        } catch {
            print("❌ Error calculating total today minutes on app launch: \(error)")
            return 0
        }
    }
    
    // 🔥 実際のスケジュール目標を取得
    private func getActualDailyGoalMinutes() async -> Int {
        do {
            let scheduleViewModel = ScheduleViewModel(container: diContainer)
            await scheduleViewModel.loadData()
            
            if let todaySchedule = scheduleViewModel.getTodayActiveSchedule() {
                print("✅ App launch - found active schedule: \(todaySchedule.dailyGoalMinutes) minutes")
                return todaySchedule.dailyGoalMinutes
            } else {
                print("⚠️ App launch - no active schedule found")
                return 0
            }
        } catch {
            print("❌ Error getting schedule data on app launch: \(error)")
            return 0
        }
    }
    
    // 🔥 実際の連続日数を取得
    private func getActualStreakDays() async -> Int {
        do {
            let streakDays = try await diContainer.studyRecordUseCase.getOverallConsecutiveStudyDays()
            print("✅ App launch - streak days: \(streakDays)")
            return streakDays
        } catch {
            print("❌ Error getting streak days on app launch: \(error)")
            return 0
        }
    }
    
    // アクティブセッションチェックメソッド（既存）
    private func checkForActiveStudySession() {
        print("🔍 Checking for active study session...")
        guard let activeSession = StudySessionManager.shared.getActiveSession() else {
            print("📭 No active session found")
            return
        }
        
        print("🔍 Found active session for subject ID: \(activeSession.subjectId)")
        
        Task {
            do {
                let subjects = try await diContainer.subjectUseCase.getAllSubjects()
                if let subject = subjects.first(where: { $0.id == activeSession.subjectId }) {
                    print("✅ Found matching subject: \(subject.name)")
                    await MainActor.run {
                        self.activeSubject = subject
                        self.showingSessionRestoreAlert = true
                    }
                } else {
                    print("⚠️ Subject not found, clearing active session")
                    StudySessionManager.shared.clearActiveSession()
                }
            } catch {
                print("❌ Error loading subjects: \(error)")
                StudySessionManager.shared.clearActiveSession()
            }
        }
    }
}

// 学習記録のメイン画面（既存）
struct StudyRecordMainView: View {
    var body: some View {
        let _ = print("📚 StudyRecordMainView body called")
        
        SubjectListView()
            .onAppear {
                print("📚 StudyRecordMainView onAppear")
            }
    }
}

#Preview {
    ContentView()
        .environment(DIContainer.shared)
}
