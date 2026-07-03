//
//  StudyRecordRepository.swift
//  Studies
//

import Foundation
import SwiftData
import os

@MainActor
class StudyRecordRepository: StudyRecordRepositoryProtocol {
    private let modelContainer: ModelContainer
    
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }
    
    func fetchAll() async throws -> [StudyRecord] {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<StudyRecordModel>(
            sortBy: [SortDescriptor(\.studyDate, order: .reverse)]
        )
        let models = try context.fetch(descriptor)
        return models.map { $0.toDomainEntity() }
    }
    
    func fetchRecords(for subjectId: UUID) async throws -> [StudyRecord] {
        let context = modelContainer.mainContext
        let id = subjectId // 明示的に変数に格納
        let descriptor = FetchDescriptor<StudyRecordModel>(
            predicate: #Predicate { record in
                record.subjectId == id
            },
            sortBy: [SortDescriptor(\.studyDate, order: .reverse)]
        )
        let models = try context.fetch(descriptor)
        return models.map { $0.toDomainEntity() }
    }
    
    func fetchRecords(for date: Date) async throws -> [StudyRecord] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let context = modelContainer.mainContext
        
        let startDate = startOfDay
        let endDate = endOfDay
        let descriptor = FetchDescriptor<StudyRecordModel>(
            predicate: #Predicate { record in
                record.studyDate >= startDate && record.studyDate < endDate
            },
            sortBy: [SortDescriptor(\.studyDate, order: .reverse)]
        )
        let models = try context.fetch(descriptor)
        return models.map { $0.toDomainEntity() }
    }
    
    func fetchRecords(from startDate: Date, to endDate: Date) async throws -> [StudyRecord] {
        let context = modelContainer.mainContext
        let fromDate = startDate
        let toDate = endDate
        let descriptor = FetchDescriptor<StudyRecordModel>(
            predicate: #Predicate { record in
                record.studyDate >= fromDate && record.studyDate <= toDate
            },
            sortBy: [SortDescriptor(\.studyDate, order: .reverse)]
        )
        let models = try context.fetch(descriptor)
        return models.map { $0.toDomainEntity() }
    }
    
    func save(_ record: StudyRecord) async throws {
        let context = modelContainer.mainContext
        let model = StudyRecordModel.fromDomainEntity(record)
        context.insert(model)
        try context.save()
    }
    
    // ← 修正: isArchivedプロパティの更新を追加
    func update(_ record: StudyRecord) async throws {
        let context = modelContainer.mainContext
        let recordId = record.id // 明示的に変数に格納
        let descriptor = FetchDescriptor<StudyRecordModel>(
            predicate: #Predicate { model in
                model.id == recordId
            }
        )
        let models = try context.fetch(descriptor)
        if let model = models.first {
            model.subjectId = record.subjectId
            model.studyDate = record.studyDate
            model.duration = record.duration
            model.isArchived = record.isArchived  // ← 追加: これが抜けていました！

            try context.save()
        } else {
            Logger.data.warning("Record not found for update: \(recordId)")
        }
    }
    
    func delete(_ record: StudyRecord) async throws {
        let context = modelContainer.mainContext
        let recordId = record.id // 明示的に変数に格納
        let descriptor = FetchDescriptor<StudyRecordModel>(
            predicate: #Predicate { model in
                model.id == recordId
            }
        )
        let models = try context.fetch(descriptor)
        if let model = models.first {
            context.delete(model)
            try context.save()
        }
    }
}
