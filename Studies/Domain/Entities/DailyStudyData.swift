//
//  DailyStudyData.swift
//  Studies
//
//  Created by kasahara takuma on 2025/08/08.
//


//
//  DailyStudyData.swift
//  Studies
//
//  Created by takuma on 2025/08/08.
//

import Foundation

struct DailyStudyData: Identifiable {
    let id = UUID()
    let date: Date
    let subjectStudyTimes: [SubjectStudyTime]
    
    init(date: Date, subjectStudyTimes: [SubjectStudyTime]) {
        self.date = date
        self.subjectStudyTimes = subjectStudyTimes
    }
}
