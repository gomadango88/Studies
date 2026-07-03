import Foundation
import SwiftData

@Model
final class StudyScheduleModel {
    @Attribute(.unique) var id: UUID
    var name: String
    var dailyGoalMinutes: Int
    // Bitmask representation of selected weekdays
    var selectedWeekdaysMask: Int
    var isEnabled: Bool
    var colorRed: Double
    var colorGreen: Double
    var colorBlue: Double
    var colorAlpha: Double
    var priority: Int

    @Relationship(deleteRule: .cascade, inverse: \SubjectGoalModel.schedule)
    var subjectGoals: [SubjectGoalModel]

    init(
        id: UUID = UUID(),
        name: String,
        dailyGoalMinutes: Int,
        selectedWeekdaysMask: Int,
        isEnabled: Bool,
        colorRed: Double,
        colorGreen: Double,
        colorBlue: Double,
        colorAlpha: Double,
        priority: Int = 3,
        subjectGoals: [SubjectGoalModel] = []
    ) {
        self.id = id
        self.name = name
        self.dailyGoalMinutes = dailyGoalMinutes
        self.selectedWeekdaysMask = selectedWeekdaysMask
        self.isEnabled = isEnabled
        self.colorRed = colorRed
        self.colorGreen = colorGreen
        self.colorBlue = colorBlue
        self.colorAlpha = colorAlpha
        self.priority = priority
        self.subjectGoals = subjectGoals
    }
}

@Model
final class SubjectGoalModel {
    @Attribute(.unique) var id: UUID
    var subjectId: UUID
    var subjectName: String
    var subjectColorRed: Double
    var subjectColorGreen: Double
    var subjectColorBlue: Double
    var subjectColorAlpha: Double
    var goalMinutes: Int
    var isEnabled: Bool

    @Relationship var schedule: StudyScheduleModel?

    init(
        id: UUID = UUID(),
        subjectId: UUID,
        subjectName: String,
        subjectColorRed: Double,
        subjectColorGreen: Double,
        subjectColorBlue: Double,
        subjectColorAlpha: Double,
        goalMinutes: Int,
        isEnabled: Bool
    ) {
        self.id = id
        self.subjectId = subjectId
        self.subjectName = subjectName
        self.subjectColorRed = subjectColorRed
        self.subjectColorGreen = subjectColorGreen
        self.subjectColorBlue = subjectColorBlue
        self.subjectColorAlpha = subjectColorAlpha
        self.goalMinutes = goalMinutes
        self.isEnabled = isEnabled
    }
}

