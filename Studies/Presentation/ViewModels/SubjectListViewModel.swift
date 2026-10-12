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
            Task { await SubjectSpotlightIndexer.reindexAll() }
        } catch {
            errorMessage = String(localized: "教材の読み込みに失敗しました: \(error.localizedDescription)")
        }

        isLoading = false
    }
    
    func deleteSubject(_ subject: Subject) async {
        guard let useCase = subjectUseCase else { return }
        
        do {
            try await useCase.deleteSubject(subject)
            await loadSubjects()
        } catch {
            errorMessage = String(localized: "教材の削除に失敗しました: \(error.localizedDescription)")
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
            errorMessage = String(localized: "並び順の保存に失敗しました: \(error.localizedDescription)")
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
            errorMessage = String(localized: "並び順の保存に失敗しました: \(error.localizedDescription)")
            await loadSubjects()
        }
    }
    
    func persistSubjectOrder() async {
        guard let useCase = subjectUseCase else { return }
        
        do {
            try await useCase.reorderSubjects(subjects)
        } catch {
            errorMessage = String(localized: "並び順の保存に失敗しました: \(error.localizedDescription)")
        }
    }
    
    // MARK: - シンプル版ピン留め機能

    func toggleSubjectPin(_ subject: Subject) async {
        // 前のタスクをキャンセル（重複防止）
        currentTask?.cancel()

        currentTask = Task {
            await simpleTogglePin(subject)
        }

        await currentTask?.value
    }

    private func simpleTogglePin(_ subject: Subject) async {
        guard let useCase = subjectUseCase else { return }

        var updatedSubject = subject
        updatedSubject.isPinned.toggle()
        do {
            try await useCase.updateSubject(updatedSubject)

            await loadSubjects()

        } catch {
            Logger.ui.error("Failed to toggle pin: \(error)")
            errorMessage = String(localized: "ピン留めの更新に失敗しました: \(error.localizedDescription)")
        }
    }

    func moveSubjectWithinPinned(subject: Subject, to destinationIndex: Int) async {
        await simpleMoveWithinSection(subject: subject, to: destinationIndex, isPinned: true)
    }
    
    func moveSubjectWithinRegular(subject: Subject, to destinationIndex: Int) async {
        await simpleMoveWithinSection(subject: subject, to: destinationIndex, isPinned: false)
    }
    
    private func simpleMoveWithinSection(subject: Subject, to destinationIndex: Int, isPinned: Bool) async {
        guard let useCase = subjectUseCase else { return }

        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.2)) {
                if let currentIndex = subjects.firstIndex(where: { $0.id == subject.id }) {
                    var tempSubjects = subjects
                    let movedSubject = tempSubjects.remove(at: currentIndex)

                    let sectionSubjects = tempSubjects.filter { $0.isPinned == isPinned }
                    let clampedDestination = min(destinationIndex, sectionSubjects.count)

                    let pinnedSubjects = tempSubjects.filter { $0.isPinned }
                    let regularSubjects = tempSubjects.filter { !$0.isPinned }

                    if isPinned {
                        var newPinnedSubjects = pinnedSubjects
                        newPinnedSubjects.insert(movedSubject, at: clampedDestination)
                        tempSubjects = newPinnedSubjects + regularSubjects
                    } else {
                        var newRegularSubjects = regularSubjects
                        newRegularSubjects.insert(movedSubject, at: clampedDestination)
                        tempSubjects = pinnedSubjects + newRegularSubjects
                    }

                    subjects = tempSubjects
                }
            }
        }

        do {
            try await useCase.reorderSubjects(subjects)

            await loadSubjects()

        } catch {
            Logger.ui.error("Failed section move: \(error)")
            errorMessage = String(localized: "並び順の保存に失敗しました: \(error.localizedDescription)")
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

