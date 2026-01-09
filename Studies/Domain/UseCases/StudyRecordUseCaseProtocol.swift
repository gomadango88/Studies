//
//  StudyRecordUseCaseProtocol.swift
//  Studies
//

import Foundation

// ← StudyChartDataUseCaseプロトコル定義（1箇所のみ）
protocol StudyChartDataUseCase {
    func getRecordsForDateRange(from startDate: Date, to endDate: Date) async throws -> [StudyRecord]
    func getActiveRecordsForDateRange(from startDate: Date, to endDate: Date) async throws -> [StudyRecord]
}

// ← 修正: StudyChartDataUseCaseを継承
protocol StudyRecordUseCaseProtocol: StudyChartDataUseCase {
    // 基本メソッド
    func getAllRecords() async throws -> [StudyRecord]
    func getRecordsForSubject(_ subjectId: UUID) async throws -> [StudyRecord]
    func getRecordsForDate(_ date: Date) async throws -> [StudyRecord]
    func getRecordsForDateRange(from startDate: Date, to endDate: Date) async throws -> [StudyRecord]
    func createRecord(subjectId: UUID, duration: TimeInterval, studyDate: Date?) async throws -> StudyRecord
    func updateRecord(_ record: StudyRecord) async throws
    func deleteRecord(_ record: StudyRecord) async throws
    
    // ← 追加: アーカイブ関連メソッド
    func getActiveRecords() async throws -> [StudyRecord]
    func getArchivedRecords() async throws -> [StudyRecord]
    func getActiveRecordsForDateRange(from startDate: Date, to endDate: Date) async throws -> [StudyRecord]
    func archiveRecord(_ record: StudyRecord) async throws
    func unarchiveRecord(_ record: StudyRecord) async throws
    func archiveRecordsByMonth(_ monthYear: String) async throws
    func unarchiveRecordsByMonth(_ monthYear: String) async throws
    
    // 統計メソッド
    func getTotalStudyTimeForToday() async throws -> TimeInterval
    func getTotalStudyTimeForWeek() async throws -> TimeInterval
    func getTotalStudyTimeForAllTime() async throws -> TimeInterval
    func getStudyTimeBySubject(for date: Date) async throws -> [SubjectStudyTime]
    func getWeeklyStudyData() async throws -> [DailyStudyData]
    func getConsecutiveStudyDays(for subjectId: UUID) async throws -> Int
    func getOverallConsecutiveStudyDays() async throws -> Int
}
