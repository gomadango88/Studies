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
