//
// StudySchedule.swift
// Studies
//
// Created by kasahara takuma on 2025/08/13.
//

import SwiftUI

// MARK: - Data Models

struct StudySchedule: Identifiable, Codable {
    let id: UUID
    var name: String
    var dailyGoalMinutes: Int
    var selectedWeekdays: Set<Weekday>
    var isEnabled: Bool
    var color: CodableColor
    var subjectGoals: [SubjectGoal]
    var priority: Int = 3
    
    init(
        id: UUID = UUID(),
        name: String,
        dailyGoalMinutes: Int,
        selectedWeekdays: Set<Weekday>,
        isEnabled: Bool,
        color: CodableColor,
        subjectGoals: [SubjectGoal],
        priority: Int = 3
    ) {
        self.id = id
        self.name = name
        self.dailyGoalMinutes = dailyGoalMinutes
        self.selectedWeekdays = selectedWeekdays
        self.isEnabled = isEnabled
        self.color = color
        self.subjectGoals = subjectGoals
        self.priority = priority
    }
    
    var priorityText: String {
        switch priority {
        case 1: return "最低"
        case 2: return "低"
        case 3: return "中"
        case 4: return "高"
        case 5: return "最高"
        default: return "中"
        }
    }
    
    var uiColor: Color {
        color.color
    }
}

struct SubjectGoal: Identifiable, Codable {
    let id: UUID
    let subjectId: UUID
    let subjectName: String
    let subjectColor: CodableColor
    var goalMinutes: Int
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        subjectId: UUID,
        subjectName: String,
        subjectColor: CodableColor,
        goalMinutes: Int,
        isEnabled: Bool
    ) {
        self.id = id
        self.subjectId = subjectId
        self.subjectName = subjectName
        self.subjectColor = subjectColor
        self.goalMinutes = goalMinutes
        self.isEnabled = isEnabled
    }
    
    var uiColor: Color {
        subjectColor.color
    }
}
