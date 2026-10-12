//
// WeeklyGoalScheduleView.swift
// Studies
//
// Created by kasahara takuma on 2025/08/13.
//

import SwiftUI

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
                ForEach(Calendar.localizedWeekdays()) { weekday in
                    minimalWeekdayColumn(weekday, viewModel: viewModel)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(Color(.systemGroupedBackground))
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
                    conflicts.append(String(localized: "\(weekday.fullName): 「\(topSchedule.name)」が適用されます"))
                }
            }
        }
        if !conflicts.isEmpty {
            conflictMessage = String(localized: "複数のスケジュールが重複している曜日があります。最高優先度のスケジュールが適用されます:\n\n") + conflicts.joined(separator: "\n")
            showingConflictAlert = true
        }
    }
}

// MARK: - Preview

#Preview {
    WeeklyGoalScheduleView()
        .environment(DIContainer.shared)
}
