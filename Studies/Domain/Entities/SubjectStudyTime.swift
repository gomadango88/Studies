//
//  SubjectStudyTime.swift
//  Studies
//
//  Created by kasahara takuma on 2025/08/08.
//


//
//  SubjectStudyTime.swift
//  Studies
//
//  Created by takuma on 2025/08/08.
//

import Foundation

struct SubjectStudyTime: Identifiable {
    let id = UUID()
    let subject: Subject
    let totalTime: TimeInterval
    
    init(subject: Subject, totalTime: TimeInterval) {
        self.subject = subject
        self.totalTime = totalTime
    }
}
