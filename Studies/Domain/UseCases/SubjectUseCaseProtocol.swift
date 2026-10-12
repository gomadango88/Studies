//
//  SubjectUseCaseProtocol.swift
//  Studies
//
//  Created by kasahara takuma on 2025/08/08.
//


import Foundation
import SwiftUI

protocol SubjectUseCaseProtocol {
    func getAllSubjects() async throws -> [Subject]
    func createSubject(name: String, color: Color, isPinned: Bool) async throws -> Subject
    func updateSubject(_ subject: Subject) async throws
    func deleteSubject(_ subject: Subject) async throws
    func reorderSubjects(_ subjects: [Subject]) async throws
    func validateSubjectName(_ name: String) -> ValidationResult
}

enum ValidationResult {
    case valid
    case empty
    case tooLong
    case duplicate
    
    var errorMessage: String? {
        switch self {
        case .valid:
            return nil
        case .empty:
            return String(localized: "教材名を入力してください")
        case .tooLong:
            return String(localized: "教材名は50文字以内で入力してください")
        case .duplicate:
            return String(localized: "同じ名前の教材が既に存在します")
        }
    }
}
