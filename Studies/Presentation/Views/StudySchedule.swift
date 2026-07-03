//
// StudySchedule.swift
// Studies
//
// Created by kasahara takuma on 2025/08/13.
//

import SwiftUI
import UIKit

// MARK: - Helper Functions

extension Calendar {
    /// システム設定に準拠した曜日配列を取得
    static func localizedWeekdays() -> [Weekday] {
        let calendar = Calendar.current
        let firstWeekdayIndex = calendar.firstWeekday - 1 // Calendar は1ベース、Weekday enumは0ベース
        let allWeekdays = Weekday.allCases
        
        if firstWeekdayIndex > 0 {
            // 配列を回転させてシステムの最初の曜日に合わせる
            return Array(allWeekdays[firstWeekdayIndex...] + allWeekdays[..<firstWeekdayIndex])
        } else {
            return Array(allWeekdays)
        }
    }
}

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

struct CodableColor: Codable, Equatable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
    
    init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
    
    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
    
    init(_ color: Color) {
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.red = Double(r)
        self.green = Double(g)
        self.blue = Double(b)
        self.alpha = Double(a)
    }
    
    static func == (lhs: CodableColor, rhs: CodableColor) -> Bool {
        let eps = 1e-6
        return abs(lhs.red - rhs.red) < eps &&
               abs(lhs.green - rhs.green) < eps &&
               abs(lhs.blue - rhs.blue) < eps &&
               abs(lhs.alpha - rhs.alpha) < eps
    }
}

enum Weekday: Int, CaseIterable, Identifiable, Codable {
    case sunday = 0, monday, tuesday, wednesday, thursday, friday, saturday
    
    var id: Int { rawValue }
    
    var shortName: String {
        switch self {
        case .sunday: return "日"
        case .monday: return "月"
        case .tuesday: return "火"
        case .wednesday: return "水"
        case .thursday: return "木"
        case .friday: return "金"
        case .saturday: return "土"
        }
    }
    
    var fullName: String {
        switch self {
        case .sunday: return "日曜日"
        case .monday: return "月曜日"
        case .tuesday: return "火曜日"
        case .wednesday: return "水曜日"
        case .thursday: return "木曜日"
        case .friday: return "金曜日"
        case .saturday: return "土曜日"
        }
    }
}
