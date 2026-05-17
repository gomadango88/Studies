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
    
    init(version: String = "1.0", exportDate: Date = Date(), subjects: [SubjectBackup], studyRecords: [StudyRecordBackup]) {
        self.version = version
        self.exportDate = exportDate
        self.subjects = subjects
        self.studyRecords = studyRecords
    }
}

nonisolated struct SubjectBackup: Codable, Identifiable {
    let id: UUID
    let name: String
    let colorRed: Double
    let colorGreen: Double
    let colorBlue: Double
    let isPinned: Bool
    let createdAt: Date
    
    init(from subject: SubjectModel) {
        self.id = subject.id
        self.name = subject.name
        let uiColor = UIColor(subject.color)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        self.colorRed = Double(red)
        self.colorGreen = Double(green)
        self.colorBlue = Double(blue)
        self.isPinned = subject.isPinned
        self.createdAt = subject.createdAt
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
