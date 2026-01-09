//
// SubjectListView.swift（シート表示修正版）
//

import SwiftUI

struct SubjectListView: View {
    @Environment(DIContainer.self) private var diContainer
    @State private var viewModel: SubjectListViewModel?
    @State private var showingAddSubject = false
    @State private var selectedSubject: Subject?
    @State private var isInitialized = false
    @State private var isLoading = true
    @State private var searchText = ""
    
    init() {
        print("🏗️ SubjectListView init")
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if isLoading {
                    VStack {
                        ProgressView()
                        Text("読み込み中...")
                            .padding(.top)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let viewModel = viewModel {
                    if viewModel.subjects.isEmpty {
                        emptyStateView
                    } else {
                        stableSubjectList(viewModel: viewModel)
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
        // 🔥 修正: .sheet(item:) を使用して確実な表示を実現
        .sheet(item: $selectedSubject) { subject in
            StudySessionView(subject: subject)
        }
        // 🔥 デバッグ用: selectedSubjectの変化を監視
        .onChange(of: selectedSubject) { oldValue, newValue in
            print("🔄 selectedSubject changed from: \(oldValue?.name ?? "nil") to: \(newValue?.name ?? "nil")")
        }
    }
    
    // 確実な初期化処理
    private func initializeViewModel() async {
        print("🔄 Initializing SubjectListView with DIContainer")
        
        await MainActor.run {
            isLoading = true
        }
        
        // DIContainerが利用可能になるまで待機
        var attempts = 0
        while diContainer == nil && attempts < 50 {
            print("⏳ Waiting for DIContainer... attempt \(attempts + 1)")
            try? await Task.sleep(nanoseconds: 100_000_000)
            attempts += 1
        }
        
        guard diContainer != nil else {
            print("❌ DIContainer initialization timeout")
            await MainActor.run {
                isLoading = false
            }
            return
        }
        
        print("✅ DIContainer available, creating ViewModel")
        
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
        
        print("✅ SubjectListView initialization completed")
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
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(subject.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    //if subject.isPinned {
                        //Image(systemName: "pin.fill")
                            //.font(.caption)
                            //.foregroundColor(.orange)
                    //}
                }
                
                Text("作成日: \(subject.createdAt.japaneseDateString)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .background(Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            print("📱 Subject tapped: \(subject.name) (ID: \(subject.id))")
            handleSubjectTap(subject)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                Task {
                    print("🔄 Pin toggle started for: \(subject.name)")
                    await viewModel.toggleSubjectPin(subject)
                    print("✅ Pin toggle completed for: \(subject.name)")
                }
            } label: {
                Image(systemName: subject.isPinned ? "pin.slash" : "pin")
            }
            .tint(subject.isPinned ? .gray : .orange)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                Task {
                    await viewModel.deleteSubject(subject)
                }
            } label: {
                Image(systemName: "trash")
            }
        }
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        .id(subject.id.uuidString + "-\(subject.isPinned)")
    }
    
    private var addButton: some View {
        Button {
            showingAddSubject = true
        } label: {
            Image(systemName: "plus")
                .font(.headline)
        }
    }
    
    // MARK: - Computed Properties（既存のsectionの上に追加）

    // 🔥 追加: 検索機能
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

    // 既存のpinnedSubjects、regularSubjectsメソッドは削除または更新
    private func pinnedSubjects(viewModel: SubjectListViewModel) -> [Subject] {
        return filteredPinnedSubjects // ← 変更
    }

    private func regularSubjects(viewModel: SubjectListViewModel) -> [Subject] {
        return filteredRegularSubjects // ← 変更
    }

    
    // MARK: - Methods
    
    private func handleSubjectTap(_ subject: Subject) {
        print("🎯 handleSubjectTap called for: \(subject.name) (ID: \(subject.id))")
        
        // 🔥 修正: より確実な状態更新
        DispatchQueue.main.async {
            selectedSubject = subject
            print("✅ selectedSubject set to: \(subject.name)")
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
        for index in offsets {
            if index < regularList.count {
                let subject = regularList[index]
                Task {
                    await viewModel.deleteSubject(subject)
                }
            }
        }
    }
}


#Preview {
    SubjectListView()
        .environment(DIContainer.shared)
}
