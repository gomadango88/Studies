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

    func getTotalStudyTimeForWeek() async throws -> TimeInterval {
        let calendar = Calendar.current
        let now = Date()
        guard let weekRange = calendar.dateInterval(of: .weekOfYear, for: now) else {
            return 0
        }

        let records = try await studyRecordRepository.fetchRecords(
            from: weekRange.start,
            to: weekRange.end
        )
        let activeRecords = records.filter { !$0.isArchived }
        return activeRecords.reduce(0) { $0 + $1.duration }
    }

    func getTotalStudyTimeForAllTime() async throws -> TimeInterval {
        let records = try await studyRecordRepository.fetchAll()
        let activeRecords = records.filter { !$0.isArchived }
        return activeRecords.reduce(0) { $0 + $1.duration }
    }

    func getStudyTimeBySubject(for date: Date) async throws -> [SubjectStudyTime] {
        let dayStart = Calendar.current.startOfDay(for: date)
        let records = try await studyRecordRepository.fetchRecords(for: dayStart)
        let activeRecords = records.filter { !$0.isArchived }
        let subjects = try await subjectRepository.fetchAll()

        let groupedRecords = Dictionary(grouping: activeRecords) { $0.subjectId }

        let subjectStudyTimes: [SubjectStudyTime] = subjects.compactMap { subject -> SubjectStudyTime? in
            let subjectRecords = groupedRecords[subject.id] ?? []
            let totalTime = subjectRecords.reduce(0) { $0 + $1.duration }
            guard totalTime > 0 else { return nil }
            return SubjectStudyTime(subject: subject, totalTime: totalTime)
        }

        return subjectStudyTimes
    }

    func getWeeklyStudyData() async throws -> [DailyStudyData] {
        let calendar = Calendar.current
        let now = Date()
        guard let weekRange = calendar.dateInterval(of: .weekOfYear, for: now) else {
            return []
        }

        let records = try await studyRecordRepository.fetchRecords(
            from: weekRange.start,
            to: weekRange.end
        )
        let activeRecords = records.filter { !$0.isArchived }
        let subjects = try await subjectRepository.fetchAll()

        var dailyData: [DailyStudyData] = []

        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: weekRange.start) else {
                continue
            }

            let dayStart = calendar.startOfDay(for: date)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }

            let dayRecords = activeRecords.filter { record in
                record.studyDate >= dayStart && record.studyDate < dayEnd
            }

            let groupedRecords = Dictionary(grouping: dayRecords) { $0.subjectId }

            let subjectStudyTimes: [SubjectStudyTime] = subjects.compactMap { subject -> SubjectStudyTime? in
                let subjectRecords = groupedRecords[subject.id] ?? []
                let totalTime = subjectRecords.reduce(0) { $0 + $1.duration }
                guard totalTime > 0 else { return nil }
                return SubjectStudyTime(subject: subject, totalTime: totalTime)
            }

            dailyData.append(
                DailyStudyData(
                    date: dayStart,
                    subjectStudyTimes: subjectStudyTimes
                )
            )
        }

        return dailyData
    }

    // 🆕 追加：教材別連続学習日数の計算（アクティブなレコードのみ）
    func getConsecutiveStudyDays(for subjectId: UUID) async throws -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var consecutiveDays = 0
        var currentDate = today

        // 今日から過去に向かって連続学習日数をカウント
        for _ in 0..<365 { // 最大365日まで遡る
            let records = try await getRecordsForDate(currentDate)
            let activeRecords = records.filter { !$0.isArchived }
            let hasStudyRecord = activeRecords.contains { $0.subjectId == subjectId && $0.duration > 0 }

            if hasStudyRecord {
                consecutiveDays += 1
                // 前日に移動
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) else {
                    break
                }
                currentDate = previousDay
            } else {
                // 学習記録がない日が見つかったので連続が途切れる
                break
            }
        }

        return consecutiveDays
    }

    // 🆕 追加：全体の連続学習日数の計算（アクティブなレコードのみ）
    func getOverallConsecutiveStudyDays() async throws -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var consecutiveDays = 0
        var currentDate = today

        // 今日から過去に向かって連続学習日数をカウント
        for _ in 0..<365 { // 最大365日まで遡る
            let records = try await getRecordsForDate(currentDate)
            let activeRecords = records.filter { !$0.isArchived }
            let hasSomeStudyRecord = !activeRecords.isEmpty && activeRecords.contains { $0.duration > 0 }

            if hasSomeStudyRecord {
                consecutiveDays += 1
                // 前日に移動
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) else {
                    break
                }
                currentDate = previousDay
            } else {
                // 学習記録がない日が見つかったので連続が途切れる
                break
            }
        }

        return consecutiveDays
    }
}

