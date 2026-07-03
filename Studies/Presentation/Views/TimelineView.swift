//
// TimelineView.swift
// Studies
//
// Created by takuma on 2025/08/08.
//

import SwiftUI
import WidgetKit

struct TimelineView: View {
    @Environment(DIContainer.self) private var diContainer
    @State private var viewModel: TimelineViewModel
    
    // 削除確認アラート用の状態管理
    @State private var recordToDelete: StudyRecord?
    @State private var showingDeleteAlert = false
    
    // 手動追加シート表示
    @State private var showingManualAddSheet = false
    
    init() {
        self._viewModel = State(wrappedValue: TimelineViewModel())
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.groupedRecords.isEmpty {
                    emptyStateView
                } else {
                    optimizedTimelineScrollView
                }
            }
            .navigationTitle("学習履歴")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        HapticFeedback.selection()
                        showingManualAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(viewModel.subjects.isEmpty)
                    .accessibilityLabel("手動で記録を追加")
                }
            }
            .onAppear {
                viewModel.setContainer(diContainer)
                Task {
                    await viewModel.loadAllRecords()
                }
            }
            // 削除確認アラート
            .alert("記録を削除しますか？", isPresented: $showingDeleteAlert, presenting: recordToDelete) { record in
                Button("削除", role: .destructive) {
                    Task {
                        await viewModel.deleteRecord(record)
                        
                        // 🔥 変更: ウィジェット更新は集中サービス経由
                        await updateWidgets()
                        
                        // 削除成功時の触覚フィードバック
                        HapticFeedback.success()
                    }
                }
                
                Button("キャンセル", role: .cancel) {
                    recordToDelete = nil
                }
                
            } message: { record in
                Text("この学習記録を削除します。\nこの操作は取り消せません。")
            }
            .sheet(isPresented: $showingManualAddSheet) {
                ManualRecordSheet(subjects: viewModel.subjects) { subjectId, date, duration in
                    Task {
                        await viewModel.addRecord(subjectId: subjectId, studyDate: date, duration: duration)
                        await updateWidgets()
                        HapticFeedback.success()
                    }
                }
            }
            .background(backdrop)
        }
    }
    
    // MARK: - ウィジェット更新メソッド
    private func updateWidgets() async {
        await WidgetUpdateService.update(using: diContainer)
    }
    
    
    private var backdrop: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.systemGroupedBackground), Color(.systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            LinearGradient(
                colors: [Color.blue.opacity(0.12), Color.purple.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blur(radius: 80)
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Views
    
    private var loadingView: some View {
        VStack {
            ProgressView()
                .scaleEffect(1.2)
            Text("読み込み中...")
                .foregroundColor(.secondary)
                .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "books.vertical")
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("学習記録がありません")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("学習を開始すると\nこちらに履歴が表示されます")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var optimizedTimelineScrollView: some View {
        List {
            ForEach(viewModel.groupedRecords, id: \.date) { group in
                Group {
                    CenteredRow(maxWidth: 640) {
                        TimelineDateHeader(date: group.date)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                    ForEach(group.records) { record in
                        CenteredRow(maxWidth: 640) {
                            OptimizedTimelineRecordCard(
                                record: record,
                                subject: viewModel.subjects.first { $0.id == record.subjectId },
                                onDelete: {
                                    recordToDelete = record
                                    showingDeleteAlert = true
                                }
                            )
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Timeline Components

struct TimelineDateHeader: View {
    let date: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(date.formatted(.dateTime.month().day()))
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                if date.isToday {
                    Text("今日")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.blue)
                } else if Calendar.current.isDateInYesterday(date) {
                    Text("昨日")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.gray)
                }

                Spacer()
            }

            Text(date.formatted(.dateTime.weekday(.wide)))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
}

// MARK: - Optimized Timeline Record Card

struct OptimizedTimelineRecordCard: View {
    let record: StudyRecord
    let subject: Subject?
    let onDelete: () -> Void
    
    // パフォーマンス最適化用のキャッシュ
    @State private var cachedDurationText: String = ""
    
    var body: some View {
        HStack(spacing: 12) {
            // タイムライン線とドット
            timelineDot

            // 記録カード
            recordCardContent
        }
        .padding(.leading, 12)
        .padding(.vertical, 6)
        .onAppear {
            // 表示時に一度だけ時間フォーマットを計算してキャッシュ
            if cachedDurationText.isEmpty {
                cachedDurationText = formatDuration(record.duration)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(subject?.name ?? "削除された教材")、\(cachedDurationText)、\(record.studyDate.formatted(date: .omitted, time: .shortened))")
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
    }
    
    
    private var timelineDot: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(subject?.color ?? Color.gray)
                .frame(width: 8, height: 8)

            Rectangle()
                .fill(Color.gray.opacity(0.25))
                .frame(width: 1)
                .frame(maxHeight: .infinity)
        }
        .frame(height: 56)
        .accessibilityHidden(true)
    }
    
    private var recordCardContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                if let subject = subject {
                    Text(subject.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                } else {
                    Text("削除された教材")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(cachedDurationText)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)

                Text(record.studyDate.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)時間\(minutes)分"
        } else if minutes > 0 {
            return "\(minutes)分"
        } else {
            return "1分未満"
        }
    }
}

// MARK: - Layout Helpers
private struct CenteredRow<Content: View>: View {
    let maxWidth: CGFloat
    @ViewBuilder let content: Content

    init(maxWidth: CGFloat = 600, @ViewBuilder content: () -> Content) {
        self.maxWidth = maxWidth
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            content
                .frame(maxWidth: maxWidth)
                .padding(.horizontal, 16)
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Manual Record Sheet
struct ManualRecordSheet: View {
    let subjects: [Subject]
    let onSave: (UUID, Date, TimeInterval) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedSubjectId: UUID?
    @State private var selectedDate: Date = Date()
    @State private var hours: Int = 0
    @State private var minutes: Int = 0
    
    private var endOfToday: Date {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? Date()
    }
    
    private var canSave: Bool {
        guard let _ = selectedSubjectId else { return false }
        return (hours * 60 + minutes) > 0
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("教材") {
                    if subjects.isEmpty {
                        Text("教材がありません。先に教材を作成してください。")
                            .foregroundColor(.secondary)
                    } else {
                        Picker("教材を選択", selection: $selectedSubjectId) {
                            ForEach(subjects, id: \.id) { subject in
                                Text(subject.name).tag(Optional(subject.id))
                            }
                        }
                    }
                }
                
                Section("日時") {
                    DatePicker("学習日時", selection: $selectedDate, in: ...endOfToday, displayedComponents: [.date, .hourAndMinute])
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                }
                
                Section("学習時間") {
                    HStack {
                        Spacer()
                        TwoComponentTimePicker(hours: $hours, minutes: $minutes, minuteStep: 1)
                            .frame(height: 160)
                        Spacer()
                    }
                }
            }
            .navigationTitle("手動で追加")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", systemImage: "checkmark") {
                        if let subjectId = selectedSubjectId {
                            let duration = TimeInterval(hours * 3600 + minutes * 60)
                            onSave(subjectId, selectedDate, duration)
                            dismiss()
                        }
                    }
                    .labelStyle(.iconOnly)
                    .disabled(!canSave)
                }
            }
            .onAppear {
                if selectedSubjectId == nil { selectedSubjectId = subjects.first?.id }
            }
        }
    }
}

#Preview {
    TimelineView()
        .environment(DIContainer.shared)
}

