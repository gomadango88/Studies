//
// ContentView.swift
// Studies
//
// Created by takuma on 2025/08/08.
//

import SwiftUI
import SwiftData
import WidgetKit

struct ContentView: View {
    @Environment(DIContainer.self) private var diContainer
    
    
    // セッション復元用の状態
    @State private var shouldShowActiveSession = false
    @State private var activeSubject: Subject?
    @State private var showingSessionRestoreAlert = false
    
    // タブ識別用の型安全な列挙
    enum AppTab: Hashable { case record, stats, goals, history }
    
    @State private var selectedTab: AppTab = .record
    
    var body: some View {
        
        TabView(selection: $selectedTab) {
            // 学習記録のメイン画面
            Tab("記録", systemImage: "stopwatch", value: AppTab.record) {
                StudyRecordMainView()
            }
            
            // 統計画面
            Tab("統計", systemImage: "chart.bar", value: AppTab.stats) {
                StatisticsView()
            }
            
            
            
            // 目標画面
            Tab("目標", systemImage: "flag.fill", value: AppTab.goals) {
                GoalSettingPreview()
            }
            
            // タイムライン画面
            Tab("履歴", systemImage: "clock.arrow.circlepath", value: AppTab.history) {
                TimelineView()
            }
        }
        .onAppear {
            
            
            
            // アクティブセッションのチェック
            checkForActiveStudySession()
            
            // アプリ起動時にウィジェットを更新
            Task { await WidgetUpdateService.update(using: diContainer) }
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
        // ウィジェットタップ時のURL処理
        .onOpenURL { url in
            print("Received URL: \(url)")
            handleDeepLink(url)
        }
    }
    
    // ディープリンク処理
    private func handleDeepLink(_ url: URL) {
        
        guard url.scheme == "studies" else {
            print("Unknown URL scheme: \(url.scheme ?? "nil")")
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
                print("Unknown tab name: \(tabName ?? "nil")")
            }
            return
        }
        
        print("Unknown deep link host: \(url.host ?? "nil")")
    }
    
    // アクティブセッションチェックメソッド（既存）
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
                    print("Subject not found, clearing active session")
                    StudySessionManager.shared.clearActiveSession()
                }
            } catch {
                print("Error loading subjects: \(error)")
                StudySessionManager.shared.clearActiveSession()
            }
        }
    }
}

// 学習記録のメイン画面
struct StudyRecordMainView: View {
    var body: some View {
        
        SubjectListView()
    }
}

// MARK: - Centralized Widget Update (fallback in app target)
struct WidgetUpdateService {
    static func update(using container: DIContainer) async {
        print("WidgetUpdateService: start update")
        // 1) 今日の合計分
        let studyRecordUseCase = container.studyRecordUseCase
        let totalTodayMinutes: Int
        do {
            let totalTodaySeconds = try await studyRecordUseCase.getTotalStudyTimeForToday()
            totalTodayMinutes = Int(totalTodaySeconds / 60)
            
        } catch {
            print("WidgetUpdateService: getTotalStudyTimeForToday error: \(error)")
            totalTodayMinutes = 0
        }

        // 2) 今日の目標分（スケジュール）
        let dailyGoal: Int
        let scheduleVM = ScheduleViewModel(container: container)
        await scheduleVM.loadData()
        dailyGoal = scheduleVM.getTodayActiveSchedule()?.dailyGoalMinutes ?? 0

        // 3) コンテキストと日付を定義
        let context = container.modelContainer.mainContext
        let todayStart = Calendar.current.startOfDay(for: Date())
        
        // 3) 達成状況のアップサート（条件付き）
        // 有効スケジュールがある日、または今日に学習がある日のみ記録をアップサート
        if dailyGoal > 0 || totalTodayMinutes > 0 {
            upsertOverallAchievement(context: context, date: todayStart, requiredMinutes: dailyGoal, achievedMinutes: totalTodayMinutes)
        }

        // 4) 連続日数（目標達成ベース）
        let streakDays = calculateOverallStreakFromAchievements(context: context)

        // 5) 保存してリロード
        let data = WidgetStudyGoalData(
            dailyGoal: dailyGoal,
            todayMinutes: totalTodayMinutes,
            streakDays: streakDays,
            lastUpdated: Date()
        )
        WidgetDataManager.shared.saveWidgetData(data)
        WidgetCenter.shared.reloadAllTimelines()
        print("WidgetUpdateService: finished update")
    }

    private static func upsertOverallAchievement(context: ModelContext, date: Date, requiredMinutes: Int, achievedMinutes: Int) {
        let key = DailyAchievementModel.makeKey(date: date, subjectId: nil)
        let descriptor = FetchDescriptor<DailyAchievementModel>(
            predicate: #Predicate { $0.key == key },
            sortBy: []
        )
        let achieved = achievedMinutes >= max(requiredMinutes, 0)
        do {
            if let existing = try context.fetch(descriptor).first {
                existing.requiredMinutes = requiredMinutes
                existing.achievedMinutes = achievedMinutes
                existing.achieved = achieved
                existing.computedAt = Date()
            } else {
                let model = DailyAchievementModel(
                    date: date,
                    subjectId: nil,
                    requiredMinutes: requiredMinutes,
                    achievedMinutes: achievedMinutes,
                    achieved: achieved,
                    computedAt: Date()
                )
                context.insert(model)
            }
            try context.save()
        } catch {
            print("[WidgetUpdateService] upsertOverallAchievement error: \(error)")
        }
    }

    private static func calculateOverallStreakFromAchievements(context: ModelContext) -> Int {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())

        func achievement(on date: Date) -> DailyAchievementModel? {
            let key = DailyAchievementModel.makeKey(date: date, subjectId: nil)
            let descriptor = FetchDescriptor<DailyAchievementModel>(
                predicate: #Predicate { $0.key == key },
                sortBy: []
            )
            return try? context.fetch(descriptor).first
        }

        let startDate: Date = {
            if let rec = achievement(on: todayStart), rec.achieved {
                return todayStart
            } else {
                return calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
            }
        }()

        var date = startDate
        var count = 0
        for _ in 0..<365 {
            guard let rec = achievement(on: date) else { break }
            if rec.achieved {
                count += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: date) else { break }
                date = prev
            } else {
                break
            }
        }
        return count
    }
}

#Preview {
    ContentView()
        .environment(DIContainer.shared)
}
