//
//  BackupDataModel.swift
//  Studies
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - バックアップ用データ構造
nonisolated struct BackupData: Codable {
    let version: String
    let exportDate: Date
    let subjects: [SubjectBackup]
    let studyRecords: [StudyRecordBackup]
    // v2.0以降のフィールド（旧フォーマットでは存在しないためオプショナル）
    let dailyAchievements: [DailyAchievementBackup]?
    let schedules: [StudyScheduleBackup]?

    init(
        version: String = "2.0",
        exportDate: Date = Date(),
        subjects: [SubjectBackup],
        studyRecords: [StudyRecordBackup],
        dailyAchievements: [DailyAchievementBackup]? = nil,
        schedules: [StudyScheduleBackup]? = nil
    ) {
        self.version = version
        self.exportDate = exportDate
        self.subjects = subjects
        self.studyRecords = studyRecords
        self.dailyAchievements = dailyAchievements
        self.schedules = schedules
    }
}

nonisolated struct SubjectBackup: Codable, Identifiable {
    let id: UUID
    let name: String
    let colorRed: Double
    let colorGreen: Double
    let colorBlue: Double
    let colorAlpha: Double
    let isPinned: Bool
    let createdAt: Date
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id, name, colorRed, colorGreen, colorBlue, colorAlpha, isPinned, createdAt, sortOrder
    }

    init(from subject: SubjectModel) {
        self.id = subject.id
        self.name = subject.name
        let uiColor = UIColor(subject.color)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        self.colorRed = Double(red)
        self.colorGreen = Double(green)
        self.colorBlue = Double(blue)
        self.colorAlpha = Double(alpha)
        self.isPinned = subject.isPinned
        self.createdAt = subject.createdAt
        self.sortOrder = subject.sortOrder
    }

    // 旧バージョンのバックアップ（sortOrder/colorAlpha非対応）を後方互換で読み込む
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        colorRed = try container.decode(Double.self, forKey: .colorRed)
        colorGreen = try container.decode(Double.self, forKey: .colorGreen)
        colorBlue = try container.decode(Double.self, forKey: .colorBlue)
        colorAlpha = try container.decodeIfPresent(Double.self, forKey: .colorAlpha) ?? 1.0
        isPinned = try container.decode(Bool.self, forKey: .isPinned)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
    }
}

nonisolated struct StudyRecordBackup: Codable, Identifiable {
    let id: UUID
    let subjectId: UUID
    let studyDate: Date
    let duration: TimeInterval
    let createdAt: Date
    let isArchived: Bool
    
    init(from record: StudyRecordModel) {
        self.id = record.id
        self.subjectId = record.subjectId
        self.studyDate = record.studyDate
        self.duration = record.duration
        self.createdAt = record.createdAt
        self.isArchived = record.isArchived
    }
}

// MARK: - 達成記録のバックアップ（v2.0以降）
nonisolated struct DailyAchievementBackup: Codable {
    let date: Date
    let subjectId: UUID? // nil = 全体
    let requiredMinutes: Int
    let achievedMinutes: Int
    let achieved: Bool
    let computedAt: Date

    init(from achievement: DailyAchievementModel) {
        self.date = achievement.date
        self.subjectId = achievement.subjectId
        self.requiredMinutes = achievement.requiredMinutes
        self.achievedMinutes = achievement.achievedMinutes
        self.achieved = achievement.achieved
        self.computedAt = achievement.computedAt
    }
}

// MARK: - スケジュールのバックアップ（v2.0以降）
nonisolated struct StudyScheduleBackup: Codable, Identifiable {
    let id: UUID
    let name: String
    let dailyGoalMinutes: Int
    let selectedWeekdaysMask: Int
    let isEnabled: Bool
    let colorRed: Double
    let colorGreen: Double
    let colorBlue: Double
    let colorAlpha: Double
    let priority: Int
    let subjectGoals: [SubjectGoalBackup]

    init(from schedule: StudyScheduleModel) {
        self.id = schedule.id
        self.name = schedule.name
        self.dailyGoalMinutes = schedule.dailyGoalMinutes
        self.selectedWeekdaysMask = schedule.selectedWeekdaysMask
        self.isEnabled = schedule.isEnabled
        self.colorRed = schedule.colorRed
        self.colorGreen = schedule.colorGreen
        self.colorBlue = schedule.colorBlue
        self.colorAlpha = schedule.colorAlpha
        self.priority = schedule.priority
        self.subjectGoals = schedule.subjectGoals.map { SubjectGoalBackup(from: $0) }
    }
}

nonisolated struct SubjectGoalBackup: Codable, Identifiable {
    let id: UUID
    let subjectId: UUID
    let subjectName: String
    let subjectColorRed: Double
    let subjectColorGreen: Double
    let subjectColorBlue: Double
    let subjectColorAlpha: Double
    let goalMinutes: Int
    let isEnabled: Bool

    init(from goal: SubjectGoalModel) {
        self.id = goal.id
        self.subjectId = goal.subjectId
        self.subjectName = goal.subjectName
        self.subjectColorRed = goal.subjectColorRed
        self.subjectColorGreen = goal.subjectColorGreen
        self.subjectColorBlue = goal.subjectColorBlue
        self.subjectColorAlpha = goal.subjectColorAlpha
        self.goalMinutes = goal.goalMinutes
        self.isEnabled = goal.isEnabled
    }
}
