//
// StudySchedule.swift
// Studies
//
// Created by kasahara takuma on 2025/08/13.
//

import SwiftUI
import UIKit

// MARK: - Helper Functions

extension Calendar {
    /// システム設定に準拠した曜日配列を取得
    static func localizedWeekdays() -> [Weekday] {
        let calendar = Calendar.current
        let firstWeekdayIndex = calendar.firstWeekday - 1 // Calendar は1ベース、Weekday enumは0ベース
        let allWeekdays = Weekday.allCases
        
        if firstWeekdayIndex > 0 {
            // 配列を回転させてシステムの最初の曜日に合わせる
            return Array(allWeekdays[firstWeekdayIndex...] + allWeekdays[..<firstWeekdayIndex])
        } else {
            return Array(allWeekdays)
        }
    }
}

// MARK: - Data Models

struct StudySchedule: Identifiable, Codable {
    let id: UUID
    var name: String
    var dailyGoalMinutes: Int
    var selectedWeekdays: Set<Weekday>
    var isEnabled: Bool
    var color: CodableColor
    var subjectGoals: [SubjectGoal]
    var priority: Int = 3
    
    init(
        id: UUID = UUID(),
        name: String,
        dailyGoalMinutes: Int,
        selectedWeekdays: Set<Weekday>,
        isEnabled: Bool,
        color: CodableColor,
        subjectGoals: [SubjectGoal],
        priority: Int = 3
    ) {
        self.id = id
        self.name = name
        self.dailyGoalMinutes = dailyGoalMinutes
        self.selectedWeekdays = selectedWeekdays
        self.isEnabled = isEnabled
        self.color = color
        self.subjectGoals = subjectGoals
        self.priority = priority
    }
    
    var priorityText: String {
        switch priority {
        case 1: return "最低"
        case 2: return "低"
        case 3: return "中"
        case 4: return "高"
        case 5: return "最高"
        default: return "中"
        }
    }
    
    var uiColor: Color {
        color.color
    }
}

struct SubjectGoal: Identifiable, Codable {
    let id: UUID
    let subjectId: UUID
    let subjectName: String
    let subjectColor: CodableColor
    var goalMinutes: Int
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        subjectId: UUID,
        subjectName: String,
        subjectColor: CodableColor,
        goalMinutes: Int,
        isEnabled: Bool
    ) {
        self.id = id
        self.subjectId = subjectId
        self.subjectName = subjectName
        self.subjectColor = subjectColor
        self.goalMinutes = goalMinutes
        self.isEnabled = isEnabled
    }
    
    var uiColor: Color {
        subjectColor.color
    }
}

struct CodableColor: Codable, Equatable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
    
    init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
    
    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
    
    init(_ color: Color) {
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.red = Double(r)
        self.green = Double(g)
        self.blue = Double(b)
        self.alpha = Double(a)
    }
    
    static func == (lhs: CodableColor, rhs: CodableColor) -> Bool {
        let eps = 1e-6
        return abs(lhs.red - rhs.red) < eps &&
               abs(lhs.green - rhs.green) < eps &&
               abs(lhs.blue - rhs.blue) < eps &&
               abs(lhs.alpha - rhs.alpha) < eps
    }
}

enum Weekday: Int, CaseIterable, Identifiable, Codable {
    case sunday = 0, monday, tuesday, wednesday, thursday, friday, saturday
    
    var id: Int { rawValue }
    
    var shortName: String {
        switch self {
        case .sunday: return "日"
        case .monday: return "月"
        case .tuesday: return "火"
        case .wednesday: return "水"
        case .thursday: return "木"
        case .friday: return "金"
        case .saturday: return "土"
        }
    }
    
    var fullName: String {
        switch self {
        case .sunday: return "日曜日"
        case .monday: return "月曜日"
        case .tuesday: return "火曜日"
        case .wednesday: return "水曜日"
        case .thursday: return "木曜日"
        case .friday: return "金曜日"
        case .saturday: return "土曜日"
        }
    }
}

// MARK: - Main Schedule View

struct WeeklyGoalScheduleView: View {
    @Environment(DIContainer.self) private var diContainer
    @State private var viewModel: ScheduleViewModel?
    @State private var showingScheduleEditor = false
    @State private var editingSchedule: StudySchedule?
    @State private var showingConflictAlert = false
    @State private var conflictMessage = ""
    
    var body: some View {
        NavigationStack {
            Group {
                if let viewModel = viewModel {
                    VStack(spacing: 0) {
                        minimalWeeklyCalendarView(viewModel: viewModel)
                        Divider()
                        scheduleListView(viewModel: viewModel)
                    }
                } else {
                    ProgressView("データ読み込み中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("学習スケジュール")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editingSchedule = nil
                        showingScheduleEditor = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline)
                    }
                }
            }
            .sheet(item: $editingSchedule, onDismiss: {
                editingSchedule = nil
            }) { schedule in
                if let viewModel = viewModel {
                    ScheduleEditorView(
                        schedule: schedule,
                        existingSchedules: viewModel.schedules,
                        availableSubjects: viewModel.subjects,
                        onSave: { updatedSchedule in
                            viewModel.saveSchedule(updatedSchedule)
                            checkForConflicts(viewModel: viewModel)
                        }
                    )
                }
            }
            .sheet(isPresented: $showingScheduleEditor) {
                if let viewModel = viewModel {
                    ScheduleEditorView(
                        schedule: nil,
                        existingSchedules: viewModel.schedules,
                        availableSubjects: viewModel.subjects,
                        onSave: { updatedSchedule in
                            viewModel.saveSchedule(updatedSchedule)
                            checkForConflicts(viewModel: viewModel)
                        }
                    )
                }
            }
            .alert("スケジュール競合", isPresented: $showingConflictAlert) {
                Button("OK") { }
            } message: {
                Text(conflictMessage)
            }
            .onAppear {
                if viewModel == nil {
                    viewModel = ScheduleViewModel(container: diContainer)
                }
                
                Task {
                    await viewModel?.loadData()
                }
            }
        }
    }
    
    private func minimalWeeklyCalendarView(viewModel: ScheduleViewModel) -> some View {
        VStack(spacing: 8) {
            Text("今週のスケジュール")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            HStack(spacing: 0) {
                ForEach(localizedWeekdays) { weekday in
                    minimalWeekdayColumn(weekday, viewModel: viewModel)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(Color(.systemGroupedBackground))
    }
    
    private var localizedWeekdays: [Weekday] {
        let calendar = Calendar.current
        let firstWeekday = calendar.firstWeekday
        let offset = (firstWeekday + 6) % 7
        let allWeekdays = Weekday.allCases
        return Array(allWeekdays[offset...] + allWeekdays[..<offset])
    }
    
    private func minimalWeekdayColumn(_ weekday: Weekday, viewModel: ScheduleViewModel) -> some View {
        let highestSchedule = viewModel.getHighestPrioritySchedule(for: weekday)
        let todayWeekdayIndex = Calendar.current.component(.weekday, from: Date()) - 1
        let isToday = weekday.rawValue == todayWeekdayIndex
        
        return VStack(spacing: 4) {
            Text(weekday.shortName)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(isToday ? .white : .secondary)
            
            if let schedule = highestSchedule {
                Circle()
                    .fill(schedule.uiColor)
                    .frame(width: 8, height: 8)
                Text("\(schedule.dailyGoalMinutes)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isToday ? .white : .primary)
            } else {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 8, height: 8)
                Text("−")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isToday ? Color.secondary.opacity(0.5) : Color.clear)
        )
    }
    
    private func scheduleListView(viewModel: ScheduleViewModel) -> some View {
        List {
            ForEach(viewModel.schedules, id: \.id) { schedule in
                ScheduleRowView(
                    schedule: schedule,
                    onTap: {
                        handleScheduleTap(schedule: schedule)
                    },
                    onToggle: {
                        viewModel.toggleSchedule(withId: schedule.id)
                        checkForConflicts(viewModel: viewModel)
                    },
                    onDelete: {
                        viewModel.deleteSchedule(withId: schedule.id)
                    }
                )
            }
            .onDelete { offsets in
                viewModel.deleteSchedule(atOffsets: offsets)
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    private func handleScheduleTap(schedule: StudySchedule) {
        guard !showingScheduleEditor else { return }
        editingSchedule = schedule
    }
    
    private func checkForConflicts(viewModel: ScheduleViewModel) {
        var conflicts: [String] = []
        for weekday in Weekday.allCases {
            let activeSchedules = viewModel.schedules.filter { $0.isEnabled && $0.selectedWeekdays.contains(weekday) }
            if activeSchedules.count > 1 {
                let sortedSchedules = activeSchedules.sorted { $0.priority > $1.priority }
                let topSchedule = sortedSchedules[0]
                let conflictingSchedules = sortedSchedules.dropFirst().map { $0.name }
                if !conflictingSchedules.isEmpty {
                    conflicts.append("\(weekday.fullName): 「\(topSchedule.name)」が適用されます")
                }
            }
        }
        if !conflicts.isEmpty {
            conflictMessage = "複数のスケジュールが重複している曜日があります。最高優先度のスケジュールが適用されます:\n\n" + conflicts.joined(separator: "\n")
            showingConflictAlert = true
        }
    }
}

// MARK: - Schedule Row View

struct ScheduleRowView: View {
    let schedule: StudySchedule
    let onTap: () -> Void
    let onToggle: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(schedule.uiColor)
                .frame(width: 4, height: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(schedule.name)
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    priorityBadge
                    
                    Text("\(schedule.dailyGoalMinutes)分/日")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 4) {
                    if schedule.selectedWeekdays.isEmpty {
                        Text("適用曜日なし")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(Calendar.localizedWeekdays().filter { schedule.selectedWeekdays.contains($0) }) { weekday in
                            Text(weekday.shortName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(schedule.uiColor)
                                .clipShape(Capsule())
                        }
                    }
                    
                    Spacer()
                    
                    if !schedule.subjectGoals.isEmpty {
                        HStack(spacing: 2) {
                            ForEach(schedule.subjectGoals.filter { $0.isEnabled }.prefix(3)) { subjectGoal in
                                Circle()
                                    .fill(subjectGoal.uiColor)
                                    .frame(width: 8, height: 8)
                            }
                            
                            if schedule.subjectGoals.filter({ $0.isEnabled }).count > 3 {
                                Text("+\(schedule.subjectGoals.filter { $0.isEnabled }.count - 3)")
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            
            Toggle("", isOn: Binding(
                get: { schedule.isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
            .onTapGesture {
                // Toggle自体のタップを処理するため、何もしない
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) { onDelete() } label: { Image(systemName: "trash") }
        }
    }
    
    private var priorityBadge: some View {
        HStack(spacing: 2) {
            Image(systemName: priorityIcon)
                .font(.system(size: 10))
                .foregroundColor(priorityColor)
            Text(schedule.priorityText)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(priorityColor)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(priorityColor.opacity(0.15))
        .clipShape(Capsule())
    }
    
    private var priorityIcon: String {
        switch schedule.priority {
        case 1: return "arrow.down.circle"
        case 2: return "arrow.down"
        case 3: return "minus"
        case 4: return "arrow.up"
        case 5: return "arrow.up.circle"
        default: return "minus"
        }
    }
    
    private var priorityColor: Color {
        switch schedule.priority {
        case 1: return .gray
        case 2: return .blue
        case 3: return .orange
        case 4: return .red
        case 5: return .purple
        default: return .orange
        }
    }
}

// MARK: - Preview

#Preview {
    WeeklyGoalScheduleView()
        .environment(DIContainer.shared)
}
