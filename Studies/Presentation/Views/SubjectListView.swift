//
// SubjectListView.swift（シート表示修正版)
//

import SwiftUI
import TipKit

struct SubjectListView: View {
    @Environment(DIContainer.self) private var diContainer
    @State private var viewModel: SubjectListViewModel?
    @State private var showingAddSubject = false
    @State private var selectedSubject: Subject?
    @State private var isInitialized = false
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var subjectPendingDeletion: Subject?
    
    init() {
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    VStack {
                        ProgressView()
                        Text("読み込み中...")
                            .padding(.top)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let viewModel = viewModel {
                    Group {
                        if viewModel.subjects.isEmpty {
                            emptyStateView
                        } else {
                            stableSubjectList(viewModel: viewModel)
                        }
                    }
                    .onChange(of: viewModel.subjects.isEmpty, initial: true) { _, isEmpty in
                        StudiesTipsState.hasSubjects = !isEmpty
                    }
                } else {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 60))
                            .foregroundColor(.red)
                        Text("初期化に失敗しました")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Button("再試行") {
                            Task {
                                await initializeViewModel()
                            }
                        }
                        .padding(.top)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("教材選択")
            .navigationBarTitleDisplayMode(.large)
            .searchable(
                        text: $searchText,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "教材名を検索"
                    )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    addButton
                }
            }
            .background(GradientBackdrop())
        }
        .task {
            await initializeViewModel()
        }
        .sheet(isPresented: $showingAddSubject) {
            AddSubjectView(onSubjectAdded: {
                Task {
                    await viewModel?.loadSubjects()
                }
            })
        }
        .sheet(item: $selectedSubject) { subject in
            StudySessionView(subject: subject)
        }
        .alert(
            "教材を削除しますか？",
            isPresented: Binding(
                get: { subjectPendingDeletion != nil },
                set: { isPresented in
                    if !isPresented { subjectPendingDeletion = nil }
                }
            ),
            presenting: subjectPendingDeletion
        ) { subject in
            Button("削除", role: .destructive) {
                Task {
                    await viewModel?.deleteSubject(subject)
                }
            }
            Button("キャンセル", role: .cancel) {
                subjectPendingDeletion = nil
            }
        } message: { subject in
            Text("「\(subject.name)」を削除します。この教材の学習記録は保持されますが、履歴には「削除された教材」として表示されるようになります。この操作は取り消せません。")
        }
    }
    
    private func initializeViewModel() async {
        
        await MainActor.run {
            isLoading = true
        }

        let newViewModel = SubjectListViewModel()
        newViewModel.setContainer(diContainer)
        
        await MainActor.run {
            viewModel = newViewModel
        }
        
        await newViewModel.loadSubjects()
        
        await MainActor.run {
            isInitialized = true
            isLoading = false
        }
    }
    
    // MARK: - Views
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("教材を追加しましょう")
                .font(.title2)
                .fontWeight(.semibold)
            Text("右上の + ボタンから\n最初の教材を追加してください")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private func stableSubjectList(viewModel: SubjectListViewModel) -> some View {
        List {
            TipView(StartStudyTip())
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

            if searchText.isEmpty {

                Section(header: pinnedSectionHeader) {
                    if filteredPinnedSubjects.isEmpty {
                        HStack {
                            Text("ピン留めされた教材はありません")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(filteredPinnedSubjects, id: \.id) { subject in
                            stableSubjectRow(subject, isPinnedSection: true, viewModel: viewModel)
                        }
                        .onMove { source, destination in
                            handleMovePinned(from: source, to: destination, viewModel: viewModel)
                        }
                    }
                }
                
                Section(header: regularSectionHeader) {
                    ForEach(filteredRegularSubjects, id: \.id) { subject in
                        stableSubjectRow(subject, isPinnedSection: false, viewModel: viewModel)
                    }
                    .onMove { source, destination in
                        handleMoveRegular(from: source, to: destination, viewModel: viewModel)
                    }
                    .onDelete { offsets in
                        handleDelete(at: offsets, viewModel: viewModel)
                    }
                }
                
            } else {
               
                Section {
                    let allFilteredSubjects = filteredPinnedSubjects + filteredRegularSubjects
                    
                    if allFilteredSubjects.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("「\(searchText)」に一致する教材がありません")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("キーワードを変更して再度検索してください")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(allFilteredSubjects, id: \.id) { subject in
                            stableSubjectRow(subject, isPinnedSection: subject.isPinned, viewModel: viewModel)
                        }
                    }
                } header: {
                    if !searchText.isEmpty && !(filteredPinnedSubjects + filteredRegularSubjects).isEmpty {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("検索結果 (\(filteredPinnedSubjects.count + filteredRegularSubjects.count)件)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    
    private var pinnedSectionHeader: some View {
        HStack {
            Image(systemName: "pin.fill")
                .font(.caption)
                .foregroundColor(.orange)
                .rotationEffect(.degrees(45))
            Text("ピン留め")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
    }
    
    private var regularSectionHeader: some View {
        HStack {
            Text("教材")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private func stableSubjectRow(_ subject: Subject, isPinnedSection: Bool, viewModel: SubjectListViewModel) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(subject.color)
                .frame(width: 4, height: 50)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(subject.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                }

                Text("作成日: \(subject.createdAt.japaneseDateString)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .background(Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            handleSubjectTap(subject)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(subject.name)、作成日 \(subject.createdAt.japaneseDateString)")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("タップして学習を開始")
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                Task {
                    await viewModel.toggleSubjectPin(subject)
                }
            } label: {
                Image(systemName: subject.isPinned ? "pin.slash" : "pin")
            }
            .tint(subject.isPinned ? .gray : .orange)
            // セクションヘッダの「ピン留め(Pinned)」と表示文字列が衝突するため、
            // 動詞用法(Pinする操作)はキーを明示的に分離する。
            // また、String型の三項式はTextと同じくverbatimオーバーロードが選ばれるため、
            // 両分岐とも明示的にString(localized:)でローカライズ済みの値にしてから渡す
            .accessibilityLabel(
                subject.isPinned
                    ? String(localized: "ピン留めを解除")
                    : String(localized: "action.pin", defaultValue: "ピン留め")
            )
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                subjectPendingDeletion = subject
            } label: {
                Image(systemName: "trash")
            }
            .accessibilityLabel("削除")
        }
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        .id(subject.id.uuidString + "-\(subject.isPinned)")
    }

    private var addButton: some View {
        Button {
            AddSubjectTip().invalidate(reason: .actionPerformed)
            showingAddSubject = true
        } label: {
            Image(systemName: "plus")
                .font(.headline)
        }
        .popoverTip(AddSubjectTip())
        .accessibilityLabel("教材を追加")
    }
    
    // MARK: - Computed Properties

    private var filteredPinnedSubjects: [Subject] {
        guard let viewModel = viewModel else { return [] }
        let pinnedList = viewModel.subjects.filter { $0.isPinned }.sorted { $0.sortOrder < $1.sortOrder }
        
        if searchText.isEmpty {
            return pinnedList
        } else {
            return pinnedList.filter { subject in
                subject.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    private var filteredRegularSubjects: [Subject] {
        guard let viewModel = viewModel else { return [] }
        let regularList = viewModel.subjects.filter { !$0.isPinned }.sorted { $0.sortOrder < $1.sortOrder }
        
        if searchText.isEmpty {
            return regularList
        } else {
            return regularList.filter { subject in
                subject.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    private func pinnedSubjects(viewModel: SubjectListViewModel) -> [Subject] {
        return filteredPinnedSubjects
    }

    private func regularSubjects(viewModel: SubjectListViewModel) -> [Subject] {
        return filteredRegularSubjects
    }

    // MARK: - Methods

    private func handleSubjectTap(_ subject: Subject) {
        StartStudyTip().invalidate(reason: .actionPerformed)
        DispatchQueue.main.async {
            selectedSubject = subject
        }
    }
    
    private func handleMovePinned(from source: IndexSet, to destination: Int, viewModel: SubjectListViewModel) {
        guard let sourceIndex = source.first else { return }
        let pinnedList = pinnedSubjects(viewModel: viewModel)
        guard sourceIndex < pinnedList.count, destination <= pinnedList.count else { return }
        
        let destinationIndex = destination > sourceIndex ? destination - 1 : destination
        let subjectToMove = pinnedList[sourceIndex]
        
        Task {
            await viewModel.moveSubjectWithinPinned(subject: subjectToMove, to: destinationIndex)
        }
    }
    
    private func handleMoveRegular(from source: IndexSet, to destination: Int, viewModel: SubjectListViewModel) {
        guard let sourceIndex = source.first else { return }
        let regularList = regularSubjects(viewModel: viewModel)
        guard sourceIndex < regularList.count, destination <= regularList.count else { return }
        
        let destinationIndex = destination > sourceIndex ? destination - 1 : destination
        let subjectToMove = regularList[sourceIndex]
        
        Task {
            await viewModel.moveSubjectWithinRegular(subject: subjectToMove, to: destinationIndex)
        }
    }
    
    private func handleDelete(at offsets: IndexSet, viewModel: SubjectListViewModel) {
        let regularList = regularSubjects(viewModel: viewModel)
        guard let index = offsets.first, index < regularList.count else { return }
        subjectPendingDeletion = regularList[index]
    }
}


#Preview {
    SubjectListView()
        .environment(DIContainer.shared)
}
