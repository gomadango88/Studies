import Foundation
import SwiftData

@Model
final class DailyAchievementModel {
    @Attribute(.unique) var key: String // yyyy-MM-dd|<subjectId or overall>
    var date: Date // startOfDay
    var subjectId: UUID? // nil = overall
    var requiredMinutes: Int // goal minutes required that day (0 if no goal)
    var achievedMinutes: Int
    var achieved: Bool // whether requiredMinutes was met
    var computedAt: Date

    init(date: Date, subjectId: UUID?, requiredMinutes: Int, achievedMinutes: Int, achieved: Bool, computedAt: Date = Date()) {
        let start = Calendar.current.startOfDay(for: date)
        self.date = start
        self.subjectId = subjectId
        self.requiredMinutes = requiredMinutes
        self.achievedMinutes = achievedMinutes
        self.achieved = achieved
        self.computedAt = computedAt
        self.key = DailyAchievementModel.makeKey(date: start, subjectId: subjectId)
    }

    static func makeKey(date: Date, subjectId: UUID?) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        let dayString = formatter.string(from: Calendar.current.startOfDay(for: date))
        let subjectPart = subjectId?.uuidString ?? "overall"
        return "\(dayString)|\(subjectPart)"
    }
}
