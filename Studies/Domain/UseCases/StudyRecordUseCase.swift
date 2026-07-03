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

    // ← 追加: アクティブなレコードのみ取得
    func getActiveRecords() async throws -> [StudyRecord] {
        let allRecords = try await studyRecordRepository.fetchAll()
        return allRecords.filter { !$0.isArchived }
    }

    // ← 追加: アーカイブされたレコードのみ取得
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

    // ← 追加: アクティブなレコードのみ日付で取得
    func getActiveRecordsForDate(_ date: Date) async throws -> [StudyRecord] {
        let records = try await studyRecordRepository.fetchRecords(for: date)
        return records.filter { !$0.isArchived }
    }

    func getRecordsForDateRange(from startDate: Date, to endDate: Date) async throws -> [StudyRecord] {
        try await studyRecordRepository.fetchRecords(from: startDate, to: endDate)
    }

    // ← 追加: アクティブなレコードのみ日付範囲で取得
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

    // ← 追加: 個別レコードのアーカイブ
    func archiveRecord(_ record: StudyRecord) async throws {
        let archivedRecord = record.archived()
        try await studyRecordRepository.update(archivedRecord)
    }

    // ← 追加: 個別レコードのアーカイブ解除
    func unarchiveRecord(_ record: StudyRecord) async throws {
        let unarchivedRecord = record.unarchived()
        try await studyRecordRepository.update(unarchivedRecord)
    }

    // ← 修正: 月単位でのアーカイブ（デバッグログ付き）
    func archiveRecordsByMonth(_ monthYear: String) async throws {
        print("UseCase: Starting archive process for month: \(monthYear)")
        
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "yyyy-MM"
        monthFormatter.locale = Locale(identifier: "ja_JP")

        let allRecords = try await studyRecordRepository.fetchAll()
        print("UseCase: Total records found: \(allRecords.count)")
        
        let recordsToArchive = allRecords.filter { record in
            let recordMonth = monthFormatter.string(from: record.studyDate)
            let shouldArchive = recordMonth == monthYear && !record.isArchived
            if shouldArchive {
                print("UseCase: Record to archive: \(record.id), month: \(recordMonth)")
            }
            return shouldArchive
        }
        
        print("UseCase: Records to archive: \(recordsToArchive.count)")

        for record in recordsToArchive {
            let archivedRecord = record.archived()
            print("UseCase: Archiving record: \(record.id) -> isArchived: \(archivedRecord.isArchived)")
            try await studyRecordRepository.update(archivedRecord)
        }
        
        print("UseCase: Archive process completed for month: \(monthYear)")
    }

    // ← 修正: 月単位でのアーカイブ解除（デバッグログ付き）
    func unarchiveRecordsByMonth(_ monthYear: String) async throws {
        print("UseCase: Starting unarchive process for month: \(monthYear)")
        
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "yyyy-MM"
        monthFormatter.locale = Locale(identifier: "ja_JP")

        let allRecords = try await studyRecordRepository.fetchAll()
        print("UseCase: Total records found: \(allRecords.count)")
        
        let recordsToUnarchive = allRecords.filter { record in
            let recordMonth = monthFormatter.string(from: record.studyDate)
            let shouldUnarchive = recordMonth == monthYear && record.isArchived
            if shouldUnarchive {
                print("UseCase: Record to unarchive: \(record.id), month: \(recordMonth)")
            }
            return shouldUnarchive
        }
        
        print("UseCase: Records to unarchive: \(recordsToUnarchive.count)")

        for record in recordsToUnarchive {
            let unarchivedRecord = record.unarchived()
            print("UseCase: Unarchiving record: \(record.id) -> isArchived: \(unarchivedRecord.isArchived)")
            try await studyRecordRepository.update(unarchivedRecord)
        }
        
        print("UseCase: Unarchive process completed for month: \(monthYear)")
    }

    // MARK: - 統計メソッド（アクティブなレコードのみ対象）
    func getTotalStudyTimeForToday() async throws -> TimeInterval {
        let today = Calendar.current.startOfDay(for: Date())
        let records = try await studyRecordRepository.fetchRecords(for: today)
        let activeRecords = records.filter { !$0.isArchived }
        return activeRecords.reduce(0) { $0 + $1.duration }
    }

}

