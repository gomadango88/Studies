//
//  SubjectUseCase.swift
//  Studies
//
//  Created by kasahara takuma on 2025/08/08.
//


import Foundation
import SwiftUI

class SubjectUseCase: SubjectUseCaseProtocol {
    private let repository: SubjectRepositoryProtocol
    
    init(repository: SubjectRepositoryProtocol) {
        self.repository = repository
    }
    
    func getAllSubjects() async throws -> [Subject] {
        let subjects = try await repository.fetchAll()
        return subjects.sorted { $0.sortOrder < $1.sortOrder }
    }
    
    func createSubject(name: String, color: Color, isPinned: Bool) async throws -> Subject {
        let validation = validateSubjectName(name)
        guard validation == .valid else {
            throw SubjectUseCaseError.validationFailed(validation)
        }
        
        let existingSubjects = try await repository.fetchAll()
        let maxSortOrder = existingSubjects.map(\.sortOrder).max() ?? -1
        
        let newSubject = Subject(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            color: color,
            sortOrder: maxSortOrder + 1,
            isPinned: isPinned
        )
        
        try await repository.save(newSubject)
        return newSubject
    }
    
    func updateSubject(_ subject: Subject) async throws {
        let validation = validateSubjectName(subject.name)
        guard validation == .valid else {
            throw SubjectUseCaseError.validationFailed(validation)
        }
        
        try await repository.update(subject)
    }
    
    func deleteSubject(_ subject: Subject) async throws {
        try await repository.delete(subject)
    }
    
    func reorderSubjects(_ subjects: [Subject]) async throws {
        let reorderedSubjects = subjects.enumerated().map { index, subject in
            Subject(
                id: subject.id,
                name: subject.name,
                color: subject.color,
                sortOrder: index,
                isPinned: subject.isPinned,
                createdAt: subject.createdAt
            )
        }
        
        try await repository.reorderSubjects(reorderedSubjects)
    }
    
    func validateSubjectName(_ name: String) -> ValidationResult {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedName.isEmpty {
            return .empty
        }
        
        if trimmedName.count > 50 {
            return .tooLong
        }
        
        // 重複チェックは実際の実装では非同期処理が必要だが、
        // 簡略化のため同期的に処理（実際のアプリでは改善が必要）
        return .valid
    }
}

enum SubjectUseCaseError: LocalizedError {
    case validationFailed(ValidationResult)
    
    var errorDescription: String? {
        switch self {
        case .validationFailed(let validation):
            return validation.errorMessage
        }
    }
}

