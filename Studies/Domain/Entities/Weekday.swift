//
// Weekday.swift
// Studies
//
// Created by kasahara takuma on 2025/08/13.
//

import Foundation

// MARK: - Helper Functions

extension Calendar {
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

enum Weekday: Int, CaseIterable, Identifiable, Codable {
    case sunday = 0, monday, tuesday, wednesday, thursday, friday, saturday

    var id: Int { rawValue }

    var shortName: String {
        switch self {
        case .sunday: return String(localized: "日")
        case .monday: return String(localized: "月")
        case .tuesday: return String(localized: "火")
        case .wednesday: return String(localized: "水")
        case .thursday: return String(localized: "木")
        case .friday: return String(localized: "金")
        case .saturday: return String(localized: "土")
        }
    }

    var fullName: String {
        switch self {
        case .sunday: return String(localized: "日曜日")
        case .monday: return String(localized: "月曜日")
        case .tuesday: return String(localized: "火曜日")
        case .wednesday: return String(localized: "水曜日")
        case .thursday: return String(localized: "木曜日")
        case .friday: return String(localized: "金曜日")
        case .saturday: return String(localized: "土曜日")
        }
    }
}
