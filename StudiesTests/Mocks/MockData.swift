//
//  MockData.swift
//  Studies
//
//  Created by kasahara takuma on 2025/08/08.
//


import Foundation
import SwiftUI
@testable import Studies

struct MockData {
    static let sampleSubjects: [Subject] = [
        Subject(name: "数学", color: .blue, sortOrder: 0),
        Subject(name: "英語", color: .green, sortOrder: 1),
        Subject(name: "物理", color: .red, sortOrder: 2)
    ]
    
    static let sampleStudyRecords: [StudyRecord] = [
        StudyRecord(
            subjectId: sampleSubjects[0].id,
            studyDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
            duration: 3600
        ),
        StudyRecord(
            subjectId: sampleSubjects[1].id,
            studyDate: Date(),
            duration: 1800
        )
    ]
}

// MARK: - Mock Repositories

final class MockSubjectRepository: SubjectRepositoryProtocol {
    var subjects: [Subject]

    init(subjects: [Subject] = []) {
        self.subjects = subjects
    }

    func fetchAll() async throws -> [Subject] {
        subjects
    }

    func save(_ subject: Subject) async throws {
        subjects.append(subject)
    }

    func update(_ subject: Subject) async throws {
        guard let index = subjects.firstIndex(where: { $0.id == subject.id }) else { return }
        subjects[index] = subject
    }

    func delete(_ subject: Subject) async throws {
        subjects.removeAll { $0.id == subject.id }
    }

    func reorderSubjects(_ subjects: [Subject]) async throws {
        self.subjects = subjects
    }
}

final class MockStudyRecordRepository: StudyRecordRepositoryProtocol {
    var records: [StudyRecord]
    var saveCallCount = 0
    var updateCallCount = 0
    var deleteCallCount = 0

    init(records: [StudyRecord] = []) {
        self.records = records
    }

    func fetchAll() async throws -> [StudyRecord] {
        records
    }

    func fetchRecords(for subjectId: UUID) async throws -> [StudyRecord] {
        records.filter { $0.subjectId == subjectId }
    }

    func fetchRecords(for date: Date) async throws -> [StudyRecord] {
        let calendar = Calendar.current
        return records.filter { calendar.isDate($0.studyDate, inSameDayAs: date) }
    }

    func fetchRecords(from startDate: Date, to endDate: Date) async throws -> [StudyRecord] {
        records.filter { $0.studyDate >= startDate && $0.studyDate <= endDate }
    }

    func save(_ record: StudyRecord) async throws {
        saveCallCount += 1
        records.append(record)
    }

    func update(_ record: StudyRecord) async throws {
        updateCallCount += 1
        guard let index = records.firstIndex(where: { $0.id == record.id }) else { return }
        records[index] = record
    }

    func delete(_ record: StudyRecord) async throws {
        deleteCallCount += 1
        records.removeAll { $0.id == record.id }
    }
}
