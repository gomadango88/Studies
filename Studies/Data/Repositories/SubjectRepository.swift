//
// SubjectRepository.swift
// Studies
//
// Created by takuma on 2025/08/08.
//

import Foundation
import SwiftData
import os

@MainActor
class SubjectRepository: SubjectRepositoryProtocol {
    private let modelContainer: ModelContainer
    
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }
    
    func fetchAll() async throws -> [Subject] {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<SubjectModel>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        
        let models = try context.fetch(descriptor)
        let subjects = models.map { $0.toDomainEntity() }
        return subjects
    }

    func save(_ subject: Subject) async throws {
        let context = modelContainer.mainContext
        let model = SubjectModel.fromDomainEntity(subject)

        context.insert(model)
        try context.save()
    }
    
    func update(_ subject: Subject) async throws {
        let context = modelContainer.mainContext
        let subjectId = subject.id // 明示的に変数に格納
        
        let descriptor = FetchDescriptor<SubjectModel>(
            predicate: #Predicate { model in
                model.id == subjectId
            }
        )
        
        let models = try context.fetch(descriptor)
        if let model = models.first {
            model.name = subject.name
            model.color = subject.color
            model.sortOrder = subject.sortOrder
            model.isPinned = subject.isPinned

            try context.save()
        } else {
            Logger.data.warning("Subject not found with id: \(subjectId)")
        }
    }
    
    func delete(_ subject: Subject) async throws {
        let context = modelContainer.mainContext
        let subjectId = subject.id // 明示的に変数に格納
        
        let descriptor = FetchDescriptor<SubjectModel>(
            predicate: #Predicate { model in
                model.id == subjectId
            }
        )
        
        let models = try context.fetch(descriptor)
        if let model = models.first {
            context.delete(model)
            try context.save()
        }
    }
    
    func reorderSubjects(_ subjects: [Subject]) async throws {
        let context = modelContainer.mainContext
        
        for subject in subjects {
            let subjectId = subject.id // 明示的に変数に格納
            
            let descriptor = FetchDescriptor<SubjectModel>(
                predicate: #Predicate { model in
                    model.id == subjectId
                }
            )
            
            let models = try context.fetch(descriptor)
            if let model = models.first {
                model.sortOrder = subject.sortOrder
                model.isPinned = subject.isPinned
            }
        }
        
        try context.save()
    }
}

