//
//  StudyRecordUseCaseProtocol.swift
//  Studies
//

import Foundation

protocol StudyChartDataUseCase {
    func getRecordsForDateRange(from startDate: Date, to endDate: Date) async throws -> [StudyRecord]
    func getActiveRecordsForDateRange(from startDate: Date, to endDate: Date) async throws -> [StudyRecord]
}

protocol StudyRecordUseCaseProtocol: StudyChartDataUseCase {
    func getAllRecords() async throws -> [StudyRecord]
    func getRecordsForSubject(_ subjectId: UUID) async throws -> [StudyRecord]
    func getRecordsForDate(_ date: Date) async throws -> [StudyRecord]
    func getRecordsForDateRange(from startDate: Date, to endDate: Date) async throws -> [StudyRecord]
    func createRecord(subjectId: UUID, duration: TimeInterval, studyDate: Date?) async throws -> StudyRecord
    func updateRecord(_ record: StudyRecord) async throws
    func deleteRecord(_ record: StudyRecord) async throws

    func getActiveRecords() async throws -> [StudyRecord]
    func getArchivedRecords() async throws -> [StudyRecord]
    func getActiveRecordsForDate(_ date: Date) async throws -> [StudyRecord]
    func getActiveRecordsForDateRange(from startDate: Date, to endDate: Date) async throws -> [StudyRecord]
    func archiveRecord(_ record: StudyRecord) async throws
    func unarchiveRecord(_ record: StudyRecord) async throws
    func archiveRecordsByMonth(_ monthYear: String) async throws
    func unarchiveRecordsByMonth(_ monthYear: String) async throws

    func getTotalStudyTimeForToday() async throws -> TimeInterval
}
