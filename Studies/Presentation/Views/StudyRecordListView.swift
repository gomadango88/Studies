//
//  StudyRecordListView.swift
//  Studies
//
//  月別学習記録一覧（削除・アーカイブ機能）
//

import SwiftUI
import Combine
import os

// MARK: - データモデル
struct MonthlySummary: Identifiable, Equatable {
    let id = UUID()
    let monthYear: String // "2024-03"
    let displayMonthYear: String // "2024年3月"
    let totalDuration: TimeInterval
    let recordCount: Int
    let subjectBreakdown: [String: TimeInterval] // 科目別時間
    let isArchived: Bool // ← 追加: この月がアーカイブ状態かどうか
    
    var totalHours: Int {
        Int(totalDuration / 3600)
    }
    
    var totalMinutes: Int {
        Int((totalDuration.truncatingRemainder(dividingBy: 3600)) / 60)
    }
    
    var formattedTotalTime: String {
        if totalHours > 0 {
            return "\(totalHours)時間\(totalMinutes)分"
        } else {
            return "\(Int(totalDuration / 60))分"
        }
    }
    
    var topSubjects: String {
        let sortedSubjects = subjectBreakdown
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { $0.key }
        return sortedSubjects.joined(separator: "・")
    }
}

// MARK: - ViewModel
@MainActor
class StudyRecordListViewModel: ObservableObject {
    @Published var activeMonthlySummaries: [MonthlySummary] = []
    @Published var archivedMonthlySummaries: [MonthlySummary] = []
    @Published var isLoading = false
    @Published var showingArchived = false // ← 追加: アーカイブ表示モード
    
    private var studyRecordUseCase: StudyRecordUseCaseProtocol
    private var subjectUseCase: SubjectUseCaseProtocol
    private let calendar = Calendar.current
    
    private let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
    
    private let displayMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
    
    init(studyRecordUseCase: StudyRecordUseCaseProtocol, subjectUseCase: SubjectUseCaseProtocol) {
        self.studyRecordUseCase = studyRecordUseCase
        self.subjectUseCase = subjectUseCase
    }
    
    // ← 追加: 依存関係の更新メソッド
    func updateDependencies(studyRecordUseCase: StudyRecordUseCaseProtocol, subjectUseCase: SubjectUseCaseProtocol) {
        self.studyRecordUseCase = studyRecordUseCase
        self.subjectUseCase = subjectUseCase
    }
    
    func loadData() async {
        isLoading = true
        do {
            // アクティブとアーカイブの両方を読み込み
            let activeRecords = try await studyRecordUseCase.getActiveRecords()
            let archivedRecords = try await studyRecordUseCase.getArchivedRecords()
            let subjects = try await subjectUseCase.getAllSubjects()

            // アクティブデータの月別サマリー作成
            activeMonthlySummaries = createMonthlySummaries(from: activeRecords, subjects: subjects, isArchived: false)
            // アーカイブデータの月別サマリー作成
            archivedMonthlySummaries = createMonthlySummaries(from: archivedRecords, subjects: subjects, isArchived: true)
        } catch {
            Logger.data.error("データ読み込みエラー: \(error)")
        }
        isLoading = false
    }
    
    private func createMonthlySummaries(from records: [StudyRecord], subjects: [Subject], isArchived: Bool) -> [MonthlySummary] {
        let monthlyGroups = Dictionary(grouping: records) { record in
            monthFormatter.string(from: record.studyDate)
        }
        
        var summaries: [MonthlySummary] = []
        for (monthKey, records) in monthlyGroups {
            guard let monthDate = monthFormatter.date(from: monthKey) else { continue }
            let totalDuration = records.reduce(0) { $0 + $1.duration }
            let recordCount = records.count
            
            var subjectBreakdown: [String: TimeInterval] = [:]
            for record in records {
                if let subject = subjects.first(where: { $0.id == record.subjectId }) {
                    subjectBreakdown[subject.name, default: 0] += record.duration
                }
            }
            
            let summary = MonthlySummary(
                monthYear: monthKey,
                displayMonthYear: displayMonthFormatter.string(from: monthDate),
                totalDuration: totalDuration,
                recordCount: recordCount,
                subjectBreakdown: subjectBreakdown,
                isArchived: isArchived
            )
            summaries.append(summary)
        }
        
        return summaries.sorted { summary1, summary2 in
            guard let date1 = monthFormatter.date(from: summary1.monthYear),
                  let date2 = monthFormatter.date(from: summary2.monthYear) else {
                return false
            }
            return date1 > date2
        }
    }
    
    func archiveMonth(_ summary: MonthlySummary) async {
        do {
            try await studyRecordUseCase.archiveRecordsByMonth(summary.monthYear)
            await loadData()
        } catch {
            Logger.data.error("Archive error for month \(summary.monthYear): \(error)")
        }
    }

    func unarchiveMonth(_ summary: MonthlySummary) async {
        do {
            try await studyRecordUseCase.unarchiveRecordsByMonth(summary.monthYear)
            await loadData()
        } catch {
            Logger.data.error("Unarchive error for month \(summary.monthYear): \(error)")
        }
    }

    func deleteMonth(_ summary: MonthlySummary) async {
        do {
            let allRecords = try await studyRecordUseCase.getAllRecords()
            let recordsToDelete = allRecords.filter { record in
                monthFormatter.string(from: record.studyDate) == summary.monthYear
            }

            for record in recordsToDelete {
                try await studyRecordUseCase.deleteRecord(record)
            }

            await loadData()
        } catch {
            Logger.data.error("Delete error for month \(summary.monthYear): \(error)")
        }
    }
}

// MARK: - メインビュー
struct StudyRecordListView: View {
    @Environment(DIContainer.self) private var di
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: StudyRecordListViewModel
    @State private var showingActionSheet = false
    @State private var selectedAction: ActionType?
    @State private var monthToProcess: MonthlySummary?
    
    enum ActionType {
        case archive, unarchive, delete
        
        var title: String {
            switch self {
            case .archive: return "アーカイブ"
            case .unarchive: return "復元"
            case .delete: return "完全削除"
            }
        }
        
        var message: String {
            switch self {
            case .archive: return "グラフ表示から除外しますが、データは保持されます"
            case .unarchive: return "グラフ表示に復元します"
            case .delete: return "データを完全に削除します（復元できません）"
            }
        }
    }
    
    // ← 修正: Environment DIContainerを使用
    init() {
        // 一時的にsharedを使用し、onAppearで正しいDIContainerで再初期化
        self._viewModel = StateObject(wrappedValue: StudyRecordListViewModel(
            studyRecordUseCase: DIContainer.shared.studyRecordUseCase,
            subjectUseCase: DIContainer.shared.subjectUseCase
        ))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 説明文
                VStack(spacing: 8) {
                    Text("学習記録の蓄積によりグラフの動作が重い場合は、ここで過去のデータを管理できます。アーカイブされた記録はグラフから除外しますが、データは保持されます。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal)
                    
                    Divider()
                        .padding(.horizontal)
                }
                .padding(.top, 8)
                .padding(.bottom, 12)
                
                // タブ切り替え
                Picker("表示モード", selection: $viewModel.showingArchived) {
                    Text("アクティブ").tag(false)
                    Text("アーカイブ").tag(true)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.bottom)
                
                // メインコンテンツ
                Group {
                    if viewModel.isLoading {
                        ProgressView("読み込み中...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        monthlySummaryList
                    }
                }
            }
            .navigationTitle("学習記録管理")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // ← 修正: 正しいDIContainerでViewModelを再設定
                setupViewModel()
            }
            .task {
                await viewModel.loadData()
            }
            .confirmationDialog(
                selectedAction?.title ?? "",
                isPresented: $showingActionSheet,
                titleVisibility: .visible
            ) {
                if let action = selectedAction {
                    Button(action.title, role: action == .delete ? .destructive : .none) {
                        Task {
                            await performAction(action)
                        }
                    }
                    Button("キャンセル", role: .cancel) { }
                }
            } message: {
                if let action = selectedAction,
                   let month = monthToProcess {
                    Text("\(month.displayMonthYear)(\(month.recordCount)件): \(action.message)")
                }
            }
        }
    }
    
    // ← 追加: ViewModelのセットアップ
    private func setupViewModel() {
        // Environment DIContainerが利用可能になった時点で再設定
        viewModel.updateDependencies(
            studyRecordUseCase: di.studyRecordUseCase,
            subjectUseCase: di.subjectUseCase
        )
    }
    
    private var monthlySummaryList: some View {
        List {
            let summaries = viewModel.showingArchived ? viewModel.archivedMonthlySummaries : viewModel.activeMonthlySummaries
            
            if summaries.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: viewModel.showingArchived ? "archivebox" : "calendar.badge.clock")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text(viewModel.showingArchived ? "アーカイブされたデータがありません" : "学習記録がありません")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .listRowBackground(Color.clear)
            } else {
                ForEach(summaries) { summary in
                    MonthlySummaryRow(
                        summary: summary,
                        isArchived: viewModel.showingArchived,
                        onAction: { action in
                            monthToProcess = summary
                            selectedAction = action
                            showingActionSheet = true
                        }
                    )
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    private func performAction(_ action: ActionType) async {
        guard let month = monthToProcess else { return }

        switch action {
        case .archive:
            await viewModel.archiveMonth(month)
        case .unarchive:
            await viewModel.unarchiveMonth(month)
        case .delete:
            await viewModel.deleteMonth(month)
        }
    }
}

// MARK: - 月別サマリー行
struct MonthlySummaryRow: View {
    let summary: MonthlySummary
    let isArchived: Bool
    let onAction: (StudyRecordListView.ActionType) -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // 月表示
            VStack {
                Text(monthNumber)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(isArchived ? .secondary : .primary)
                Text(yearText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 44)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(summary.displayMonthYear)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(isArchived ? .secondary : .primary)
                    
                    if isArchived {
                        Image(systemName: "archivebox.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    Spacer()
                    
                    Text(summary.formattedTotalTime)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(isArchived ? .secondary : .primary)
                }
                
                HStack {
                    Text("\(summary.recordCount)件の記録")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if !summary.topSubjects.isEmpty {
                        Text(summary.topSubjects)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            
            // アクションボタン
            Menu {
                if isArchived {
                    Button {
                        onAction(.unarchive)
                    } label: {
                        Label("復元", systemImage: "arrow.uturn.backward")
                    }
                } else {
                    Button {
                        onAction(.archive)
                    } label: {
                        Label("アーカイブ", systemImage: "archivebox")
                    }
                }
                
                Button(role: .destructive) {
                    onAction(.delete)
                } label: {
                    Label("完全削除", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 8)
        .opacity(isArchived ? 0.7 : 1.0)
    }
    
    private var monthNumber: String {
        let components = summary.monthYear.components(separatedBy: "-")
        guard components.count == 2,
              let month = Int(components[1]) else { return "?" }
        return "\(month)"
    }
    
    private var yearText: String {
        let components = summary.monthYear.components(separatedBy: "-")
        guard components.count == 2 else { return "?" }
        return components[0]
    }
}

// MARK: - プレビュー
#Preview("学習記録管理") {
    StudyRecordListView()
        .environment(DIContainer.shared)
}
