//
// StudyGoal.swift
// Studies
//
// Created by kasahara takuma on 2025/08/13.
//

import SwiftUI
import SwiftData
import os

// MARK: - Data Models

struct StudyGoal {
    let id = UUID()
    let subjectId: UUID?
    let subjectName: String
    let subjectColor: Color
    let dailyGoalMinutes: Int
    let isEnabled: Bool
}

struct StudyProgress {
    let subjectId: UUID?
    let subjectName: String
    let todayMinutes: Int
    let weekMinutes: Int
    let monthMinutes: Int
    let streakDays: Int
}

// MARK: - Custom Progress Bar with Automatic Subtle Gradient

struct CustomProgressBar: View {
    let progress: CGFloat
    let color: Color
    let height: CGFloat
    let cornerRadius: CGFloat
    let useGradient: Bool = true

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(.systemGray5))

                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(progressBarFill)
                    .frame(width: geometry.size.width * max(0, min(1, progress)))
                    .animation(.easeInOut(duration: 0.7), value: progress)
            }
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("達成率")
        .accessibilityValue("\(Int(max(0, min(1, progress)) * 100))%")
    }
    
    private var progressBarFill: some ShapeStyle {
        if useGradient {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        color.opacity(0.65),
                        color,
                        color.opacity(0.95)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        } else {
            return AnyShapeStyle(color)
        }
    }
}
// MARK: - Goal View Model

@Observable
class GoalViewModel {
    private let container: DIContainer
    private var scheduleViewModel: ScheduleViewModel?
    
    private var modelContext: ModelContext { container.modelContainer.mainContext }
    
    var goals: [StudyGoal] = []
    var progress: [StudyProgress] = []
    var subjects: [Subject] = []
    var studyRecords: [StudyRecord] = []
    var hasActiveSchedule = false
    
    init(container: DIContainer) {
        self.container = container
    }
    
    func setScheduleViewModel(_ scheduleViewModel: ScheduleViewModel) {
        self.scheduleViewModel = scheduleViewModel
    }
    
    @MainActor
    func loadData() async {
        do {
            subjects = try await container.subjectUseCase.getAllSubjects()
            await loadGoals()
            await loadProgress()
        } catch {
            Logger.ui.error("データ読み込みエラー: \(error)")
        }
    }

    @MainActor
    private func loadGoals() async {
        guard let scheduleVM = scheduleViewModel else {
            hasActiveSchedule = false
            goals = []
            return
        }
        
        let todaySchedule = scheduleVM.getTodayActiveSchedule()
        
        if let schedule = todaySchedule {
            hasActiveSchedule = true
            goals = []
            
            for subjectGoal in schedule.subjectGoals where subjectGoal.isEnabled {
                if let subject = subjects.first(where: { $0.id == subjectGoal.subjectId }) {
                    let studyGoal = StudyGoal(
                        subjectId: subject.id,
                        subjectName: subject.name,
                        subjectColor: subject.color,
                        dailyGoalMinutes: subjectGoal.goalMinutes,
                        isEnabled: true
                    )
                    goals.append(studyGoal)
                }
            }
            
            let overallGoal = StudyGoal(
                subjectId: nil,
                subjectName: "全体",
                subjectColor: .purple,
                dailyGoalMinutes: schedule.dailyGoalMinutes,
                isEnabled: true
            )
            goals.append(overallGoal)
        } else {
            hasActiveSchedule = false
            goals = []
        }
    }
    
    @MainActor
    private func loadProgress() async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let monthStart = calendar.dateInterval(of: .month, for: today)?.start ?? today
        
        do {
            let todayRecords = try await container.studyRecordUseCase.getActiveRecordsForDateRange(
                from: today,
                to: Date()
            )

            let weekRecords = try await container.studyRecordUseCase.getActiveRecordsForDateRange(
                from: weekStart,
                to: Date()
            )

            let monthRecords = try await container.studyRecordUseCase.getActiveRecordsForDateRange(
                from: monthStart,
                to: Date()
            )
            
            progress = []
            
            for goal in goals.filter({ $0.subjectId != nil }) {
                guard let subjectId = goal.subjectId else { continue }

                let todayTime = calculateTotalTime(for: subjectId, in: todayRecords)
                let weekTime = calculateTotalTime(for: subjectId, in: weekRecords)
                let monthTime = calculateTotalTime(for: subjectId, in: monthRecords)

                // 達成記録の書き込みはセッション保存時とウィジェット更新時に行うため、ここでは読み取りのみ
                let streak = AchievementService.calculateStreak(context: modelContext, subjectId: subjectId)

                progress.append(StudyProgress(
                    subjectId: subjectId,
                    subjectName: goal.subjectName,
                    todayMinutes: Int(todayTime / 60),
                    weekMinutes: Int(weekTime / 60),
                    monthMinutes: Int(monthTime / 60),
                    streakDays: streak
                ))
            }
            
            let totalTodayTime = todayRecords.reduce(0) { $0 + $1.duration }
            let totalWeekTime = weekRecords.reduce(0) { $0 + $1.duration }
            let totalMonthTime = monthRecords.reduce(0) { $0 + $1.duration }

            let overallStreak = AchievementService.calculateStreak(context: modelContext, subjectId: nil)

            let overallProgress = StudyProgress(
                subjectId: nil,
                subjectName: "全体",
                todayMinutes: Int(totalTodayTime / 60),
                weekMinutes: Int(totalWeekTime / 60),
                monthMinutes: Int(totalMonthTime / 60),
                streakDays: overallStreak
            )
            progress.append(overallProgress)
            
        } catch {
            Logger.ui.error("進捗データ読み込みエラー: \(error)")
        }
    }
    
    private func calculateTotalTime(for subjectId: UUID, in records: [StudyRecord]) -> TimeInterval {
        return records
            .filter { $0.subjectId == subjectId }
            .reduce(0) { $0 + $1.duration }
    }
    
    @MainActor
    func refreshData() async {
        await loadGoals()
        await loadProgress()
    }
}

// MARK: - Main Goal Setting View

struct GoalSettingView: View {
    @Environment(DIContainer.self) private var diContainer
    @State private var viewModel: GoalViewModel?
    @State private var scheduleViewModel: ScheduleViewModel?
    @State private var showingScheduleEditor = false
    
    var body: some View {
        NavigationStack {
            Group {
                if let viewModel = viewModel {
                    if viewModel.hasActiveSchedule {
                        if !viewModel.goals.isEmpty {
                            dailyGoalsView(viewModel: viewModel)
                        } else {
                            noSubjectGoalsView
                        }
                    } else {
                        noScheduleView
                    }
                } else {
                    ProgressView("データ読み込み中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("今日の目標")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("編集") {
                        showingScheduleEditor = true
                    }
                    .accessibilityLabel("目標を編集")

                }
            }
            .sheet(isPresented: $showingScheduleEditor) {
                WeeklyGoalScheduleView()
                    .onDisappear {
                        Task {
                            await scheduleViewModel?.loadData()
                            await viewModel?.refreshData()
                        }
                    }
            }
            .onAppear {
                if viewModel == nil {
                    scheduleViewModel = ScheduleViewModel(container: diContainer)
                    viewModel = GoalViewModel(container: diContainer)
                    viewModel?.setScheduleViewModel(scheduleViewModel!)
                }
                
                Task {
                    await scheduleViewModel?.loadData()
                    await viewModel?.loadData()
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .ignoresSafeArea(.container, edges: .top)
    }
    
    private var noScheduleView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            VStack(spacing: 12) {
                Text("目標が設定されていません")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("今日に適用される学習スケジュールがありません。\n「編集」ボタンからスケジュールを作成してください。")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
            
            Button {
                showingScheduleEditor = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("スケジュールを作成")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var noSubjectGoalsView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "target")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            VStack(spacing: 12) {
                Text("教材別目標が未設定です")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("スケジュールは設定されていますが、教材別の目標が設定されていません。\n「編集」ボタンから教材別目標を追加してください。")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
            
            Button {
                showingScheduleEditor = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("教材別目標を設定")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func dailyGoalsView(viewModel: GoalViewModel) -> some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if let overallGoal = viewModel.goals.first(where: { $0.subjectName == "全体" }),
                   let overallProgress = viewModel.progress.first(where: { $0.subjectName == "全体" }) {
                    DailySummaryCard(goal: overallGoal, progress: overallProgress)
                }
                
                ForEach(Array(zip(
                    viewModel.goals.filter { $0.isEnabled && $0.subjectName != "全体" },
                    viewModel.progress.filter { $0.subjectName != "全体" }
                )), id: \.0.id) { goal, progress in
                    DailyGoalCard(goal: goal, progress: progress)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Daily Summary Card

struct DailySummaryCard: View {
    let goal: StudyGoal
    let progress: StudyProgress
    
    private var achievementPercentage: Int {
        guard goal.dailyGoalMinutes > 0 else { return 0 }
        let percentage = Double(progress.todayMinutes) / Double(goal.dailyGoalMinutes) * 100
        return Int(min(percentage, 100))
    }
    
    private var progressValue: Double {
        guard goal.dailyGoalMinutes > 0 else { return 0 }
        return min(Double(progress.todayMinutes) / Double(goal.dailyGoalMinutes), 1.0)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text("今日の学習")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text("\(progress.todayMinutes) / \(goal.dailyGoalMinutes) 分")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Image(systemName: progress.todayMinutes >= goal.dailyGoalMinutes ? "checkmark.circle.fill" : "clock")
                    .font(.system(size: 30))
                    .foregroundColor(progress.todayMinutes >= goal.dailyGoalMinutes ? .green : .orange)
                    .accessibilityHidden(true)
            }

            CustomProgressBar(
                progress: progressValue,
                color: goal.subjectColor,
                height: 10,
                cornerRadius: 6
            )
            
            HStack {
                Text("\(achievementPercentage)% 達成")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("目標達成: \(progress.streakDays)日連続")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("今日の学習、\(progress.todayMinutes)分 / \(goal.dailyGoalMinutes)分、\(achievementPercentage)%達成、\(progress.streakDays)日連続")
    }
}

// MARK: - Daily Goal Card

struct DailyGoalCard: View {
    let goal: StudyGoal
    let progress: StudyProgress
    
    var progressPercentage: Double {
        guard goal.dailyGoalMinutes > 0 else { return 0.0 }
        return min(Double(progress.todayMinutes) / Double(goal.dailyGoalMinutes), 1.0)
    }
    
    private var achievementPercentage: Int {
        guard goal.dailyGoalMinutes > 0 else { return 0 }
        let percentage = Double(progress.todayMinutes) / Double(goal.dailyGoalMinutes) * 100
        return Int(min(percentage, 100))
    }
    
    private var accessibilitySummary: String {
        if progress.todayMinutes >= goal.dailyGoalMinutes {
            return "\(goal.subjectName)、\(progress.todayMinutes)分 / \(goal.dailyGoalMinutes)分、\(achievementPercentage)%達成、目標達成"
        } else {
            let remainingMinutes = max(goal.dailyGoalMinutes - progress.todayMinutes, 0)
            return "\(goal.subjectName)、\(progress.todayMinutes)分 / \(goal.dailyGoalMinutes)分、\(achievementPercentage)%達成、残り\(remainingMinutes)分"
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 4)
                .fill(goal.subjectColor)
                .frame(width: 4, height: 60)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(goal.subjectName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text("\(progress.todayMinutes) / \(goal.dailyGoalMinutes) 分")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }

                CustomProgressBar(
                    progress: progressPercentage,
                    color: goal.subjectColor,
                    height: 8,
                    cornerRadius: 4
                )
                
                HStack {
                    Text("\(achievementPercentage)% 達成")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if progress.todayMinutes >= goal.dailyGoalMinutes {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            
                            Text("達成！")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        }
                    } else {
                        let remainingMinutes = max(goal.dailyGoalMinutes - progress.todayMinutes, 0)
                        Text("残り \(remainingMinutes) 分")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }
}

// MARK: - Preview

#if DEBUG && !WIDGET_EXTENSION
#Preview {
    GoalSettingView()
        .environment(DIContainer.shared)
}
#else
#Preview {
    DailySummaryCard(
        goal: StudyGoal(
            subjectId: nil,
            subjectName: "全体",
            subjectColor: .purple,
            dailyGoalMinutes: 120,
            isEnabled: true
        ),
        progress: StudyProgress(
            subjectId: nil,
            subjectName: "全体",
            todayMinutes: 75,
            weekMinutes: 300,
            monthMinutes: 1200,
            streakDays: 7
        )
    )
    .padding()
}
#endif

