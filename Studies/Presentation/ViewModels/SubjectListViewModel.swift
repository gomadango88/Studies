//
// SubjectListViewModel.swift（Task型エラー修正完全版）
//

import Foundation
import SwiftUI
import os

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
    
    // Task型にジェネリック引数を指定
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
    
    // MARK: - シンプル版ピン留め機能
    
    func toggleSubjectPin(_ subject: Subject) async {
        // 前のタスクをキャンセル（重複防止）
        currentTask?.cancel()
        
        // 新しいタスクで処理
        currentTask = Task {
            await simpleTogglePin(subject)
        }
        
        await currentTask?.value
    }
    
    // シンプルなピン留めトグル（楽観的更新なし）
    private func simpleTogglePin(_ subject: Subject) async {
        guard let useCase = subjectUseCase else { return }
        
        // Step 1: データベース更新のみ
        var updatedSubject = subject
        updatedSubject.isPinned.toggle()
        do {
            try await useCase.updateSubject(updatedSubject)
            
            // Step 2: データ再読み込み（SwiftUIが自動でUI更新）
            await loadSubjects()
            
        } catch {
            Logger.ui.error("Failed to toggle pin: \(error)")
            errorMessage = "ピン留めの更新に失敗しました: \(error.localizedDescription)"
        }
    }
    
    // 移動処理も簡素化
    func moveSubjectWithinPinned(subject: Subject, to destinationIndex: Int) async {
        await simpleMoveWithinSection(subject: subject, to: destinationIndex, isPinned: true)
    }
    
    func moveSubjectWithinRegular(subject: Subject, to destinationIndex: Int) async {
        await simpleMoveWithinSection(subject: subject, to: destinationIndex, isPinned: false)
    }
    
    // 修正版: 正確な並び替え処理
    private func simpleMoveWithinSection(subject: Subject, to destinationIndex: Int, isPinned: Bool) async {
        guard let useCase = subjectUseCase else { return }

        // 楽観的UI更新（即座にUIを更新）
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
            // 正確なsortOrder計算でバッチ更新（1回の保存処理にまとめる）
            try await useCase.reorderSubjects(subjects)

            // 最終的にデータベースから再読み込み（整合性確保）
            await loadSubjects()

        } catch {
            Logger.ui.error("Failed section move: \(error)")
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
}

