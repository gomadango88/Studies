//
// StudySchedule.swift
// Studies
//
// Created by kasahara takuma on 2025/08/13.
//

import SwiftUI
import WidgetKit

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
    let id = UUID()
    let subjectId: UUID
    let subjectName: String
    let subjectColor: CodableColor
    var goalMinutes: Int
    var isEnabled: Bool
    
    var uiColor: Color {
        subjectColor.color
    }
}

struct CodableColor: Codable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
    
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

// MARK: - Schedule View Model

@Observable
class ScheduleViewModel {
    private let container: DIContainer
    var schedules: [StudySchedule] = []
    var subjects: [Subject] = []
    
    init(container: DIContainer) {
        self.container = container
    }
    
    @MainActor
    func loadData() async {
        do {
            subjects = try await container.subjectUseCase.getAllSubjects()
            loadSchedules()
        } catch {
            print("データ読み込みエラー: \(error)")
        }
    }
    
    private func loadSchedules() {
        if let data = UserDefaults.standard.data(forKey: "StudySchedules"),
           let savedSchedules = try? JSONDecoder().decode([StudySchedule].self, from: data) {
            schedules = savedSchedules
        } else {
            createDefaultSchedules()
        }
    }
    
    func saveSchedules() {
        if let data = try? JSONEncoder().encode(schedules) {
            UserDefaults.standard.set(data, forKey: "StudySchedules")
        }
    }
    
    private func createDefaultSchedules() {
        let defaultSchedule = StudySchedule(
            name: "基本スケジュール",
            dailyGoalMinutes: 120,
            selectedWeekdays: [.monday, .tuesday, .wednesday, .thursday, .friday],
            isEnabled: true,
            color: CodableColor(.blue),
            subjectGoals: [],
            priority: 3
        )
        
        schedules = [defaultSchedule]
        saveSchedules()
    }
    
    // スケジュール保存時にウィジェット更新
    func saveSchedule(_ schedule: StudySchedule) {
        if let index = schedules.firstIndex(where: { $0.id == schedule.id }) {
            schedules[index] = schedule
        } else {
            schedules.append(schedule)
        }
        
        saveSchedules()
        
        // ウィジェット更新
        Task {
            await updateWidgetAfterScheduleChange()
        }
    }
    
    // スケジュール削除時にウィジェット更新
    func deleteSchedule(atOffsets offsets: IndexSet) {
        schedules.remove(atOffsets: offsets)
        saveSchedules()
        
        // ウィジェット更新
        Task {
            await updateWidgetAfterScheduleChange()
        }
    }
    
    // スケジュール削除時にウィジェット更新
    func deleteSchedule(at index: Int) {
        guard index < schedules.count else { return }
        schedules.remove(at: index)
        saveSchedules()
        
        // ウィジェット更新
        Task {
            await updateWidgetAfterScheduleChange()
        }
    }
    
    // スケジュール削除時にウィジェット更新
    func deleteSchedule(withId id: UUID) {
        schedules.removeAll { $0.id == id }
        saveSchedules()
        
        // ウィジェット更新
        Task {
            await updateWidgetAfterScheduleChange()
        }
    }
    
    // スケジュール有効化/無効化時にウィジェット更新
    func toggleSchedule(withId id: UUID) {
        if let index = schedules.firstIndex(where: { $0.id == id }) {
            schedules[index].isEnabled.toggle()
            saveSchedules()
            
            // ウィジェット更新
            Task {
                await updateWidgetAfterScheduleChange()
            }
        }
    }
    
    func getTodayActiveSchedule() -> StudySchedule? {
        let today = Calendar.current.component(.weekday, from: Date()) - 1
        let weekday = Weekday(rawValue: today) ?? .sunday
        
        return schedules
            .filter { $0.isEnabled && $0.selectedWeekdays.contains(weekday) }
            .max { $0.priority < $1.priority }
    }
    
    func getHighestPrioritySchedule(for weekday: Weekday) -> StudySchedule? {
        return schedules
            .filter { $0.isEnabled && $0.selectedWeekdays.contains(weekday) }
            .max { $0.priority < $1.priority }
    }
    
    // スケジュール変更後のウィジェット更新
    private func updateWidgetAfterScheduleChange() async {
        print("Updating widget after schedule change via WidgetUpdateService...")
        await WidgetUpdateService.update(using: container)
    }
}

// MARK: - Main Schedule View

struct WeeklyGoalSchedulePreview: View {
    @Environment(DIContainer.self) private var diContainer
    @State private var viewModel: ScheduleViewModel?
    @State private var showingScheduleEditor = false
    @State private var editingSchedule: StudySchedule?
    @State private var showingConflictAlert = false
    @State private var conflictMessage = ""
    
    var body: some View {
        NavigationView {
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
                set: { _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        onToggle()
                    }
                }
            ))
            .labelsHidden()
            .onTapGesture {
                // Toggle自体のタップを処理するため、何もしない
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
            }
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
    @State private var priority = 3
    @State private var showingPriorityConflictAlert = false
    @State private var conflictingScheduleNames: [String] = []
    @State private var showingColorPicker = false
    @State private var showingConfirmationDialog = false

    
    var body: some View {
        NavigationView {
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
                        Picker("", selection: $dailyGoal) {
                            ForEach(Array(stride(from: 1, through: 12, by: 1)), id: \.self) { hours in
                                Text("\(hours) 時間").tag(hours * 60)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
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
                            label: {
                                Text("優先度")
                            },
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
                        // プリセット色（5色）
                        ForEach([Color.blue, Color.green, Color.orange, Color.red, Color.purple], id: \.self) { color in
                            Circle()
                                .fill(color)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle()
                                        .stroke(selectedColor == color ? Color.primary : Color.clear, lineWidth: 2)
                                )
                                .onTapGesture {
                                    selectedColor = color
                                }
                        }
                        
                        // ColorPickerを配置
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
                        SubjectGoalRow(subjectGoal: subjectGoals[index]) {
                            subjectGoals.remove(at: index)
                        }
                    }
                    
                    Button(action: { showingSubjectGoalEditor = true }) {
                        Label {
                            Text("教材別目標を追加")
                                .font(.body)
                                .foregroundColor(.primary)
                        } icon: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle(schedule == nil ? "新しいスケジュール" : "スケジュールを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル", systemImage: "xmark") {
                        showingConfirmationDialog = true
                    }
                    .labelStyle(.iconOnly)
                    .confirmationDialog("新規スケジュール", isPresented: $showingConfirmationDialog, titleVisibility: .visible) {
                        Button("編集を続ける", role: .cancel) { }
                        Button("変更内容を破棄", role: .destructive) {
                            dismiss()
                        }
                    } message: {
                        Text("この新規スケジュールを破棄してもよろしいですか？")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存", systemImage: "checkmark") {
                        handleSave()
                    }
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
            }
            .sheet(isPresented: $showingSubjectGoalEditor) {
                SubjectGoalEditorView(availableSubjects: availableSubjects) { newSubjectGoal in
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
    
    // ScheduleEditorView内に追加
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
            // 編集モード: 既存のIDを保持
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
            // 新規作成モード: 新しいIDを自動生成
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

// MARK: - Supporting Views

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

struct SubjectGoalRow: View {
    let subjectGoal: SubjectGoal
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            Circle()
                .fill(subjectGoal.uiColor)
                .frame(width: 12, height: 12)
            Text(subjectGoal.subjectName)
                .font(.subheadline)
            Spacer()
            Text("\(subjectGoal.goalMinutes)分")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button {
                onDelete()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.red)
            }
        }
    }
}

struct SubjectGoalEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let availableSubjects: [Subject]
    let onSave: (SubjectGoal) -> Void
    
    @State private var selectedSubject: Subject?
    @State private var goalMinutes = 30
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("教材選択")) {
                    ForEach(availableSubjects) { subject in
                        HStack {
                            Circle()
                                .fill(subject.color)
                                .frame(width: 12, height: 12)
                            Text(subject.name)
                            Spacer()
                            if selectedSubject?.id == subject.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedSubject = subject
                        }
                    }
                }
                
                Section(header: Text("目標時間")) {
                    HStack {
                        Text("目標時間")
                        Spacer()
                        Picker("", selection: $goalMinutes) {
                            ForEach(Array(stride(from: 30, through: 240, by: 30)), id: \.self) { minutes in
                                Text("\(minutes) 分").tag(minutes)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                }
            }
            .navigationTitle("教材別目標を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル", systemImage: "xmark", action: {dismiss()})
                        .labelStyle(.iconOnly)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("追加", systemImage: "checkmark", action: {
                                            if let subject = selectedSubject {
                                                let subjectGoal = SubjectGoal(
                                                    subjectId: subject.id,
                                                    subjectName: subject.name,
                                                    subjectColor: CodableColor(subject.color),
                                                    goalMinutes: goalMinutes,
                                                    isEnabled: true
                                                )
                                                
                                                onSave(subjectGoal)
                                                dismiss()
                                            }
                                        })
                    .labelStyle(.iconOnly)
                    .fontWeight(.semibold)
                    .disabled(selectedSubject == nil)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    WeeklyGoalSchedulePreview()
        .environment(DIContainer.shared)
}

#Preview("Schedule Editor") {
    ScheduleEditorView(
        schedule: nil,
        existingSchedules: [],
        availableSubjects: []
    ) { _ in }
}

