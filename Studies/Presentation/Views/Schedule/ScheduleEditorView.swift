//
// ScheduleEditorView.swift
// Studies
//
// Created by kasahara takuma on 2025/08/13.
//

import SwiftUI

// MARK: - Schedule Editor View

struct ScheduleEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let schedule: StudySchedule?
    let existingSchedules: [StudySchedule]
    let availableSubjects: [Subject]
    let onSave: (StudySchedule) -> Void

    @State private var name = ""
    @State private var dailyGoal = 60
    @State private var selectedWeekdays: Set<Weekday> = []
    @State private var selectedColor = Color.blue
    @State private var isEnabled = true
    @State private var subjectGoals: [SubjectGoal] = []
    @State private var showingSubjectGoalEditor = false
    @State private var editingSubjectGoal: SubjectGoal? = nil
    @State private var priority = 3
    @State private var showingPriorityConflictAlert = false
    @State private var conflictingScheduleNames: [String] = []
    @State private var showingColorPicker = false
    @State private var showingConfirmationDialog = false
    @State private var initialSnapshot: ScheduleFormSnapshot? = nil

    @State private var showingDailyGoalWheel = false
    @State private var tempDailyHours = 0
    @State private var tempDailyMinutes = 0

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("基本設定")) {
                    HStack {
                        Text("スケジュール名")
                        Spacer()
                        TextField("例: 平日スケジュール", text: $name)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("1日の目標時間")
                        Spacer()
                        Button(action: { withAnimation { showingDailyGoalWheel.toggle() } }) {
                            let hours = max(0, dailyGoal / 60)
                            let minutes = max(0, dailyGoal % 60)
                            Text(String(format: "%d時間%02d分", hours, minutes))
                                .font(.body)
                                .foregroundColor(showingDailyGoalWheel ? .accentColor : .primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule().fill(Color(.secondarySystemFill))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                    if showingDailyGoalWheel {
                        HStack {
                            Spacer()
                            TwoComponentTimePicker(hours: $tempDailyHours, minutes: $tempDailyMinutes)
                                .frame(height: 160)
                            Spacer()
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .onAppear {
                            let clamped = max(0, dailyGoal)
                            tempDailyHours = min(23, clamped / 60)
                            let mins = clamped % 60
                            tempDailyMinutes = (mins / 5) * 5
                        }
                        .onChange(of: tempDailyHours) { _, newVal in
                            dailyGoal = newVal * 60 + tempDailyMinutes
                        }
                        .onChange(of: tempDailyMinutes) { _, newVal in
                            dailyGoal = tempDailyHours * 60 + newVal
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("優先度")
                            Spacer()
                            Text(priorityText(for: priority))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(priorityColor(for: priority))
                        }

                        Slider(
                            value: Binding(
                                get: { Double(priority) },
                                set: { priority = Int($0.rounded()) }
                            ),
                            in: 1...5,
                            step: 1,
                            label: { Text("優先度") },
                            minimumValueLabel: {
                                Text("最低")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            },
                            maximumValueLabel: {
                                Text("最高")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        )
                        .accentColor(priorityColor(for: priority))

                        Text("複数のスケジュールが同じ曜日で重複する場合、優先度が高いスケジュールが適用されます")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("有効")
                        Spacer()
                        Toggle("", isOn: $isEnabled)
                    }
                }

                Section(header: Text("適用曜日"), footer: Text("このスケジュールを適用する曜日を選択してください")) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                        ForEach(Calendar.localizedWeekdays()) { weekday in
                            WeekdayToggleButton(
                                weekday: weekday,
                                isSelected: selectedWeekdays.contains(weekday),
                                color: selectedColor
                            ) {
                                if selectedWeekdays.contains(weekday) {
                                    selectedWeekdays.remove(weekday)
                                } else {
                                    selectedWeekdays.insert(weekday)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section(header: Text("スケジュール色")) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 16) {
                        ForEach([Color.blue, Color.green, Color.orange, Color.red, Color.purple], id: \.self) { color in
                            Circle()
                                .fill(color)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle()
                                        .stroke(selectedColor == color ? Color.primary : Color.clear, lineWidth: 2)
                                )
                                .onTapGesture { selectedColor = color }
                        }

                        ColorPicker("", selection: $selectedColor)
                            .labelsHidden()
                            .frame(width: 30, height: 30)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.primary, lineWidth: 2)
                                    .opacity(isCustomColorSelected ? 1 : 0)
                            )
                    }
                    .padding(.vertical, 8)
                }

                Section(
                    header: Text("教材別目標（オプション）"),
                    footer: Text("特定の教材に重点を置きたい場合に設定します")
                ) {
                    ForEach(subjectGoals.indices, id: \.self) { index in
                        SubjectGoalRow(subjectGoal: subjectGoals[index])
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingSubjectGoal = subjectGoals[index]
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    subjectGoals.remove(at: index)
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                            }
                    }

                    Button(action: {
                        showingSubjectGoalEditor = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                            Text("教材別目標を追加")
                                .font(.body)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle(schedule == nil ? "新しいスケジュール" : "スケジュールを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル", systemImage: "xmark") {
                        if hasUnsavedChanges {
                            showingConfirmationDialog = true
                        } else {
                            dismiss()
                        }
                    }
                    .labelStyle(.iconOnly)
                    .confirmationDialog("新規スケジュール", isPresented: $showingConfirmationDialog, titleVisibility: .visible) {
                        Button("編集を続ける", role: .cancel) { }
                        Button("変更内容を破棄", role: .destructive) { dismiss() }
                    } message: {
                        Text("この新規スケジュールを破棄してもよろしいですか？")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存", systemImage: "checkmark") { handleSave() }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderedProminent)
                        .disabled(selectedWeekdays.isEmpty)
                }
            }
            .onAppear {
                if let schedule = schedule {
                    name = schedule.name
                    dailyGoal = schedule.dailyGoalMinutes
                    selectedWeekdays = schedule.selectedWeekdays
                    selectedColor = schedule.uiColor
                    isEnabled = schedule.isEnabled
                    subjectGoals = schedule.subjectGoals
                    priority = schedule.priority
                }
                if initialSnapshot == nil {
                    initialSnapshot = makeSnapshot()
                }
            }
            .sheet(item: $editingSubjectGoal) { goal in
                SubjectGoalEditorView(
                    availableSubjects: availableSubjects,
                    initialSubjectGoal: goal
                ) { updatedGoal in
                    if let idx = subjectGoals.firstIndex(where: { $0.id == updatedGoal.id }) {
                        subjectGoals[idx] = updatedGoal
                    }
                }
            }
            .sheet(isPresented: $showingSubjectGoalEditor) {
                SubjectGoalEditorView(
                    availableSubjects: availableSubjects,
                    initialSubjectGoal: nil
                ) { newSubjectGoal in
                    subjectGoals.append(newSubjectGoal)
                }
            }
            .alert("優先度が重複しています", isPresented: $showingPriorityConflictAlert) {
                Button("OK") { }
            } message: {
                Text(createConflictMessage())
            }
        }
    }

    private struct ScheduleFormSnapshot: Equatable {
        var name: String
        var dailyGoal: Int
        var selectedWeekdays: Set<Weekday>
        var color: CodableColor
        var isEnabled: Bool
        var subjectGoals: [SubjectGoalKey]
        var priority: Int
    }

    private struct SubjectGoalKey: Equatable {
        var subjectId: UUID
        var subjectName: String
        var subjectColor: CodableColor
        var goalMinutes: Int
        var isEnabled: Bool
    }

    private func makeSnapshot() -> ScheduleFormSnapshot {
        let goals = subjectGoals.map { goal in
            SubjectGoalKey(
                subjectId: goal.subjectId,
                subjectName: goal.subjectName,
                subjectColor: goal.subjectColor,
                goalMinutes: goal.goalMinutes,
                isEnabled: goal.isEnabled
            )
        }
        return ScheduleFormSnapshot(
            name: name,
            dailyGoal: dailyGoal,
            selectedWeekdays: selectedWeekdays,
            color: CodableColor(selectedColor),
            isEnabled: isEnabled,
            subjectGoals: goals,
            priority: priority
        )
    }

    private var hasUnsavedChanges: Bool {
        guard let initial = initialSnapshot else { return false }
        return makeSnapshot() != initial
    }

    private var isCustomColorSelected: Bool {
        let presetColors: [Color] = [.blue, .green, .orange, .red, .purple]
        return !presetColors.contains(selectedColor)
    }

    private func handleSave() {
        let conflictingSchedules = checkPriorityConflicts()
        if !conflictingSchedules.isEmpty {
            conflictingScheduleNames = conflictingSchedules
            showingPriorityConflictAlert = true
        } else {
            performSave()
        }
    }

    private func checkPriorityConflicts() -> [String] {
        let currentScheduleId = schedule?.id
        let conflictingSchedules = existingSchedules.filter { existingSchedule in
            guard existingSchedule.id != currentScheduleId else { return false }
            guard existingSchedule.isEnabled else { return false }
            guard existingSchedule.priority == priority else { return false }
            let hasWeekdayOverlap = !existingSchedule.selectedWeekdays.isDisjoint(with: selectedWeekdays)
            guard hasWeekdayOverlap else { return false }
            return true
        }
        return conflictingSchedules.map { $0.name }
    }

    private func createConflictMessage() -> String {
        if conflictingScheduleNames.count == 1 {
            return "「\(conflictingScheduleNames[0])」と優先度が重複しています。\n\n同じ曜日に適用される複数のスケジュールが同じ優先度を持つことはできません。異なる優先度を設定してください。"
        } else {
            let scheduleList = conflictingScheduleNames.joined(separator: "」、「")
            return "「\(scheduleList)」と優先度が重複しています。\n\n同じ曜日に適用される複数のスケジュールが同じ優先度を持つことはできません。異なる優先度を設定してください。"
        }
    }

    private func performSave() {
        let savedSchedule: StudySchedule
        if let existingSchedule = schedule {
            savedSchedule = StudySchedule(
                id: existingSchedule.id,
                name: name.isEmpty ? "無題のスケジュール" : name,
                dailyGoalMinutes: dailyGoal,
                selectedWeekdays: selectedWeekdays,
                isEnabled: isEnabled,
                color: CodableColor(selectedColor),
                subjectGoals: subjectGoals,
                priority: priority
            )
        } else {
            savedSchedule = StudySchedule(
                name: name.isEmpty ? "無題のスケジュール" : name,
                dailyGoalMinutes: dailyGoal,
                selectedWeekdays: selectedWeekdays,
                isEnabled: isEnabled,
                color: CodableColor(selectedColor),
                subjectGoals: subjectGoals,
                priority: priority
            )
        }
        onSave(savedSchedule)
        dismiss()
    }

    private func priorityText(for priority: Int) -> String {
        switch priority {
        case 1: return "最低"
        case 2: return "低"
        case 3: return "中"
        case 4: return "高"
        case 5: return "最高"
        default: return "中"
        }
    }

    private func priorityColor(for priority: Int) -> Color {
        switch priority {
        case 1: return .gray
        case 2: return .blue
        case 3: return .orange
        case 4: return .red
        case 5: return .purple
        default: return .orange
        }
    }

    private func priorityLevelIndicator(level: Int, current: Int, text: String) -> some View {
        VStack(spacing: 2) {
            Circle()
                .fill(level == current ? priorityColor(for: level) : Color.gray.opacity(0.3))
                .frame(width: 8, height: 8)
            Text(text)
                .font(.system(size: 8))
                .foregroundColor(level == current ? priorityColor(for: level) : .secondary)
        }
    }
}

struct WeekdayToggleButton: View {
    let weekday: Weekday
    let isSelected: Bool
    let color: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(weekday.shortName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .primary)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(isSelected ? color : Color(.systemGray6))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview("Schedule Editor") {
    ScheduleEditorView(
        schedule: nil,
        existingSchedules: [],
        availableSubjects: []
    ) { _ in }
}
