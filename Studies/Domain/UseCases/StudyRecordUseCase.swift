//
//  StudyRecordUseCase.swift
//  Studies
//
//  Created by takuma on 2025/08/08.
//

import Foundation

class StudyRecordUseCase: StudyRecordUseCaseProtocol {
    private let studyRecordRepository: StudyRecordRepositoryProtocol
    private let subjectRepository: SubjectRepositoryProtocol

    init(
        studyRecordRepository: StudyRecordRepositoryProtocol,
        subjectRepository: SubjectRepositoryProtocol
    ) {
        self.studyRecordRepository = studyRecordRepository
        self.subjectRepository = subjectRepository
    }

    func getAllRecords() async throws -> [StudyRecord] {
        try await studyRecordRepository.fetchAll()
    }

    func getActiveRecords() async throws -> [StudyRecord] {
        let allRecords = try await studyRecordRepository.fetchAll()
        return allRecords.filter { !$0.isArchived }
    }

    func getArchivedRecords() async throws -> [StudyRecord] {
        let allRecords = try await studyRecordRepository.fetchAll()
        return allRecords.filter { $0.isArchived }
    }

    func getRecordsForSubject(_ subjectId: UUID) async throws -> [StudyRecord] {
        try await studyRecordRepository.fetchRecords(for: subjectId)
    }

    func getRecordsForDate(_ date: Date) async throws -> [StudyRecord] {
        try await studyRecordRepository.fetchRecords(for: date)
    }

    func getActiveRecordsForDate(_ date: Date) async throws -> [StudyRecord] {
        let records = try await studyRecordRepository.fetchRecords(for: date)
        return records.filter { !$0.isArchived }
    }

    func getRecordsForDateRange(from startDate: Date, to endDate: Date) async throws -> [StudyRecord] {
        try await studyRecordRepository.fetchRecords(from: startDate, to: endDate)
    }

    func getActiveRecordsForDateRange(from startDate: Date, to endDate: Date) async throws -> [StudyRecord] {
        let records = try await studyRecordRepository.fetchRecords(from: startDate, to: endDate)
        return records.filter { !$0.isArchived }
    }

    func createRecord(subjectId: UUID, duration: TimeInterval, studyDate: Date? = nil) async throws -> StudyRecord {
        guard duration > 0 else {
            throw StudyRecordUseCaseError.invalidDuration
        }

        let subjects = try await subjectRepository.fetchAll()
        guard subjects.contains(where: { $0.id == subjectId }) else {
            throw StudyRecordUseCaseError.subjectNotFound
        }

        let record = StudyRecord(
            subjectId: subjectId,
            studyDate: studyDate ?? Date(),
            duration: duration
        )

        try await studyRecordRepository.save(record)
        return record
    }

    func updateRecord(_ record: StudyRecord) async throws {
        guard record.duration > 0 else {
            throw StudyRecordUseCaseError.invalidDuration
        }

        try await studyRecordRepository.update(record)
    }

    func deleteRecord(_ record: StudyRecord) async throws {
        try await studyRecordRepository.delete(record)
    }

    func archiveRecord(_ record: StudyRecord) async throws {
        let archivedRecord = record.archived()
        try await studyRecordRepository.update(archivedRecord)
    }

    func unarchiveRecord(_ record: StudyRecord) async throws {
        let unarchivedRecord = record.unarchived()
        try await studyRecordRepository.update(unarchivedRecord)
    }

    func archiveRecordsByMonth(_ monthYear: String) async throws {
        // 表示用ではなく月別突合キーのためロケール固定(和暦設定端末対策)
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "yyyy-MM"
        monthFormatter.locale = Locale(identifier: "ja_JP")

        let allRecords = try await studyRecordRepository.fetchAll()

        let recordsToArchive = allRecords.filter { record in
            let recordMonth = monthFormatter.string(from: record.studyDate)
            return recordMonth == monthYear && !record.isArchived
        }

        for record in recordsToArchive {
            let archivedRecord = record.archived()
            try await studyRecordRepository.update(archivedRecord)
        }
    }

    func unarchiveRecordsByMonth(_ monthYear: String) async throws {
        // 表示用ではなく月別突合キーのためロケール固定(和暦設定端末対策)
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "yyyy-MM"
        monthFormatter.locale = Locale(identifier: "ja_JP")

        let allRecords = try await studyRecordRepository.fetchAll()

        let recordsToUnarchive = allRecords.filter { record in
            let recordMonth = monthFormatter.string(from: record.studyDate)
            return recordMonth == monthYear && record.isArchived
        }

        for record in recordsToUnarchive {
            let unarchivedRecord = record.unarchived()
            try await studyRecordRepository.update(unarchivedRecord)
        }
    }

    // MARK: - 統計メソッド（アクティブなレコードのみ対象）
    func getTotalStudyTimeForToday() async throws -> TimeInterval {
        let today = Calendar.current.startOfDay(for: Date())
        let records = try await studyRecordRepository.fetchRecords(for: today)
        let activeRecords = records.filter { !$0.isArchived }
        return activeRecords.reduce(0) { $0 + $1.duration }
    }

}

