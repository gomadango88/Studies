//
// SubjectListViewModel.swift（Task型エラー修正完全版）
//

import Foundation
import SwiftUI

@MainActor
@Observable
class SubjectListViewModel {
    private var diContainer: DIContainer?
    
    private var subjectUseCase: SubjectUseCaseProtocol? {
        diContainer?.subjectUseCase
    }
    
    var subjects: [Subject] = []
    var isLoading = false
    var errorMessage: String?
    
    // 🔥 修正: Task型にジェネリック引数を指定
    private var currentTask: Task<Void, Never>?
    
    func setContainer(_ container: DIContainer) {
        self.diContainer = container
    }
    
    func loadSubjects() async {
        guard let useCase = subjectUseCase else { return }
        isLoading = true
        errorMessage = nil
        
        do {
            subjects = try await useCase.getAllSubjects()
        } catch {
            errorMessage = "教材の読み込みに失敗しました: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func deleteSubject(_ subject: Subject) async {
        guard let useCase = subjectUseCase else { return }
        
        do {
            try await useCase.deleteSubject(subject)
            await loadSubjects()
        } catch {
            errorMessage = "教材の削除に失敗しました: \(error.localizedDescription)"
        }
    }
    
    func reorderSubjects(from source: IndexSet, to destination: Int) async {
        guard let useCase = subjectUseCase else { return }
        
        var reorderedSubjects = subjects
        reorderedSubjects.move(fromOffsets: source, toOffset: destination)
        subjects = reorderedSubjects
        
        do {
            try await useCase.reorderSubjects(reorderedSubjects)
        } catch {
            errorMessage = "並び順の保存に失敗しました: \(error.localizedDescription)"
            await loadSubjects()
        }
    }
    
    func moveSubject(from sourceIndex: Int, to destinationIndex: Int) async {
        guard sourceIndex != destinationIndex,
              sourceIndex < subjects.count,
              destinationIndex < subjects.count else { return }
        
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.3)) {
                let movedSubject = subjects.remove(at: sourceIndex)
                subjects.insert(movedSubject, at: destinationIndex)
            }
        }
        
        do {
            try await subjectUseCase?.reorderSubjects(subjects)
        } catch {
            errorMessage = "並び順の保存に失敗しました: \(error.localizedDescription)"
            await loadSubjects()
        }
    }
    
    func persistSubjectOrder() async {
        guard let useCase = subjectUseCase else { return }
        
        do {
            try await useCase.reorderSubjects(subjects)
        } catch {
            errorMessage = "並び順の保存に失敗しました: \(error.localizedDescription)"
        }
    }
    
    // MARK: - 🔥 超シンプル版ピン留め機能
    
    func toggleSubjectPin(_ subject: Subject) async {
        // 🔥 前のタスクをキャンセル（重複防止のみ）
        currentTask?.cancel()
        
        // 🔥 新しいタスクで処理
        currentTask = Task {
            await simpleTogglePin(subject)
        }
        
        await currentTask?.value
    }
    
    // 🔥 シンプルなピン留めトグル（楽観的更新なし）
    private func simpleTogglePin(_ subject: Subject) async {
        guard let useCase = subjectUseCase else { return }
        
        do {
            print("🔄 Simple pin toggle for: \(subject.name)")
            
            // 🔥 Step 1: データベース更新のみ
            var updatedSubject = subject
            updatedSubject.isPinned.toggle()
            try await useCase.updateSubject(updatedSubject)
            
            // 🔥 Step 2: データ再読み込み（SwiftUIが自動でUI更新）
            await loadSubjects()
            
            print("✅ Simple pin toggle completed")
            
        } catch {
            print("❌ Failed to toggle pin: \(error)")
            errorMessage = "ピン留めの更新に失敗しました: \(error.localizedDescription)"
        }
    }
    
    // 🔥 移動処理も簡素化
    func moveSubjectWithinPinned(subject: Subject, to destinationIndex: Int) async {
        print("📌 moveSubjectWithinPinned: \(subject.name) to index \(destinationIndex)")
        await simpleMoveWithinSection(subject: subject, to: destinationIndex, isPinned: true)
    }
    
    func moveSubjectWithinRegular(subject: Subject, to destinationIndex: Int) async {
        print("📋 moveSubjectWithinRegular: \(subject.name) to index \(destinationIndex)")
        await simpleMoveWithinSection(subject: subject, to: destinationIndex, isPinned: false)
    }
    
    // 🔥 修正版: 正確な並び替え処理
    private func simpleMoveWithinSection(subject: Subject, to destinationIndex: Int, isPinned: Bool) async {
        guard let useCase = subjectUseCase else { return }
        
        print("🔧 Starting section move: \(subject.name) to index \(destinationIndex), isPinned: \(isPinned)")
        
        // 🔥 楽観的UI更新（即座にUIを更新）
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.2)) {
                // 一時的にUI上で移動を反映
                if let currentIndex = subjects.firstIndex(where: { $0.id == subject.id }) {
                    var tempSubjects = subjects
                    let movedSubject = tempSubjects.remove(at: currentIndex)
                    
                    // 同じセクション内での正しい位置計算
                    let sectionSubjects = tempSubjects.filter { $0.isPinned == isPinned }
                    let clampedDestination = min(destinationIndex, sectionSubjects.count)
                    
                    // セクション別に分離
                    let pinnedSubjects = tempSubjects.filter { $0.isPinned }
                    let regularSubjects = tempSubjects.filter { !$0.isPinned }
                    
                    if isPinned {
                        // ピン留めセクション内での移動
                        var newPinnedSubjects = pinnedSubjects
                        newPinnedSubjects.insert(movedSubject, at: clampedDestination)
                        tempSubjects = newPinnedSubjects + regularSubjects
                    } else {
                        // 通常セクション内での移動
                        var newRegularSubjects = regularSubjects
                        newRegularSubjects.insert(movedSubject, at: clampedDestination)
                        tempSubjects = pinnedSubjects + newRegularSubjects
                    }
                    
                    subjects = tempSubjects
                }
            }
        }
        
        do {
            // 🔥 正確なsortOrder計算でデータベース更新
            for (index, var currentSubject) in subjects.enumerated() {
                currentSubject.sortOrder = index
                try await useCase.updateSubject(currentSubject)
                print("📝 Updated sortOrder for \(currentSubject.name): \(index)")
            }
            
            // 🔥 最終的にデータベースから再読み込み（整合性確保）
            await loadSubjects()
            
            print("✅ Section move completed successfully")
            
        } catch {
            print("❌ Failed section move: \(error)")
            errorMessage = "並び順の保存に失敗しました: \(error.localizedDescription)"
            // エラー時は元に戻す
            await loadSubjects()
        }
    }
    
    // MARK: - ヘルパーメソッド
    
    func getPinnedSubjects() -> [Subject] {
        return subjects.filter { $0.isPinned }.sorted { $0.sortOrder < $1.sortOrder }
    }
    
    func getRegularSubjects() -> [Subject] {
        return subjects.filter { !$0.isPinned }.sorted { $0.sortOrder < $1.sortOrder }
    }
    
    func hasPinnedSubjects() -> Bool {
        return subjects.contains { $0.isPinned }
    }
    
    func isSubjectPinned(_ subject: Subject) -> Bool {
        return subjects.first { $0.id == subject.id }?.isPinned ?? false
    }
    
    // 🔥 デバッグ用: 現在の順序を出力
    func printCurrentOrder() {
        print("📋 Current subject order:")
        let pinnedSubjects = getPinnedSubjects()
        let regularSubjects = getRegularSubjects()
        
        print(" 📌 Pinned (\(pinnedSubjects.count)):")
        for (index, subject) in pinnedSubjects.enumerated() {
            print("   \(index): \(subject.name) (sortOrder: \(subject.sortOrder))")
        }
        
        print(" 📄 Regular (\(regularSubjects.count)):")
        for (index, subject) in regularSubjects.enumerated() {
            print("   \(index): \(subject.name) (sortOrder: \(subject.sortOrder))")
        }
    }
}
