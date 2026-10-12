//
//  StudyRecord.swift
//  Studies
//
//  Created by kasahara takuma on 2025/08/08.
//

import Foundation

struct StudyRecord: Identifiable, Equatable {
    let id: UUID
    let subjectId: UUID
    let studyDate: Date
    let duration: TimeInterval // 秒単位
    let createdAt: Date
    let isArchived: Bool
    
    init(
        id: UUID = UUID(),
        subjectId: UUID,
        studyDate: Date,
        duration: TimeInterval,
        createdAt: Date = Date(),
        isArchived: Bool = false
    ) {
        self.id = id
        self.subjectId = subjectId
        self.studyDate = studyDate
        self.duration = duration
        self.createdAt = createdAt
        self.isArchived = isArchived
    }
    
    func archived() -> StudyRecord {
        return StudyRecord(
            id: self.id,
            subjectId: self.subjectId,
            studyDate: self.studyDate,
            duration: self.duration,
            createdAt: self.createdAt,
            isArchived: true
        )
    }
    
    func unarchived() -> StudyRecord {
        return StudyRecord(
            id: self.id,
            subjectId: self.subjectId,
            studyDate: self.studyDate,
            duration: self.duration,
            createdAt: self.createdAt,
            isArchived: false
        )
    }
}

// MARK: - Extensions
extension StudyRecord {
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    var formattedStudyDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: studyDate)
    }
    
    static var mock: StudyRecord {
        StudyRecord(
            subjectId: UUID(),
            studyDate: Date(),
            duration: 3600
        )
    }
}
