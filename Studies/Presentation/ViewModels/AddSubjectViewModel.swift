//
//  AddSubjectViewModel.swift
//  Studies
//
//  Created by takuma on 2025/08/08.
//

import Foundation
import SwiftUI

@MainActor
@Observable
class AddSubjectViewModel {
    private var diContainer: DIContainer?
    private var subjectUseCase: SubjectUseCaseProtocol? {
        diContainer?.subjectUseCase
    }
    
    var subjectName = ""
    var selectedColor: Color = .blue
    var isSaving = false
    var errorMessage: String?
    
    func setContainer(_ container: DIContainer) {
        self.diContainer = container
    }
    
    func saveSubject() async -> Bool {
        guard let useCase = subjectUseCase else { return false }
        
        isSaving = true
        errorMessage = nil
        
        do {
            _ = try await useCase.createSubject(
                name: subjectName.trimmingCharacters(in: .whitespacesAndNewlines),
                color: selectedColor
            )
            isSaving = false  // ← この行を追加
            return true
        } catch {
            isSaving = false  // ← この行を追加
            if let useCaseError = error as? SubjectUseCaseError {
                errorMessage = useCaseError.errorDescription
            } else {
                errorMessage = "保存に失敗しました: \(error.localizedDescription)"
            }
            return false
        }
    }
}
