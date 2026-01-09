//
//  StudyRecordRepositoryProtocol.swift
//  Studies
//
//  Created by kasahara takuma on 2025/08/08.
//



import Foundation

protocol StudyRecordRepositoryProtocol {
    func fetchAll() async throws -> [StudyRecord]
    func fetchRecords(for subjectId: UUID) async throws -> [StudyRecord]
    func fetchRecords(for date: Date) async throws -> [StudyRecord]
    func fetchRecords(from startDate: Date, to endDate: Date) async throws -> [StudyRecord]
    func save(_ record: StudyRecord) async throws
    func update(_ record: StudyRecord) async throws
    func delete(_ record: StudyRecord) async throws
}
