//
//  StudyRecordModel.swift
//  Studies
//
//  Created by kasahara takuma on 2025/08/08.
//



import Foundation
import SwiftData

@Model
final class StudyRecordModel {
    @Attribute(.unique) var id: UUID
    var subjectId: UUID
    var studyDate: Date
    var duration: TimeInterval
    var createdAt: Date
    var isArchived: Bool = false
    
    // SwiftDataの関係性（オプショナル型に修正）
    @Relationship var subject: SubjectModel?
    
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
    
    func archived() -> StudyRecordModel {
            return StudyRecordModel(
                id: self.id,
                subjectId: self.subjectId,
                studyDate: self.studyDate,
                duration: self.duration,
                createdAt: self.createdAt,
                isArchived: true
            )
        }
        
        func unarchived() -> StudyRecordModel {
            return StudyRecordModel(
                id: self.id,
                subjectId: self.subjectId,
                studyDate: self.studyDate,
                duration: self.duration,
                createdAt: self.createdAt,
                isArchived: false
            )
        }
    
    func toDomainEntity() -> StudyRecord {
            return StudyRecord(
                id: self.id,
                subjectId: self.subjectId,
                studyDate: self.studyDate,
                duration: self.duration,
                createdAt: self.createdAt,
                isArchived: self.isArchived
            )
        }
        
        static func fromDomainEntity(_ entity: StudyRecord) -> StudyRecordModel {
            return StudyRecordModel(
                id: entity.id,
                subjectId: entity.subjectId,
                studyDate: entity.studyDate,
                duration: entity.duration,
                createdAt: entity.createdAt,
                isArchived: entity.isArchived 
            )
        }}
