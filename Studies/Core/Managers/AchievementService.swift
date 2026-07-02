//
//  AchievementService.swift
//  Studies
//

import Foundation
import SwiftData

// 達成状況(DailyAchievementModel)のアップサートと連続達成日数の計算を一箇所に集約
@MainActor
enum AchievementService {
    static func upsertAchievement(
        context: ModelContext,
        date: Date,
        subjectId: UUID?,
        requiredMinutes: Int,
        achievedMinutes: Int
    ) {
        let key = DailyAchievementModel.makeKey(date: date, subjectId: subjectId)
        let descriptor = FetchDescriptor<DailyAchievementModel>(
            predicate: #Predicate { $0.key == key },
            sortBy: []
        )
        let achieved = achievedMinutes >= max(requiredMinutes, 0)
        do {
            if let existing = try context.fetch(descriptor).first {
                existing.requiredMinutes = requiredMinutes
                existing.achievedMinutes = achievedMinutes
                existing.achieved = achieved
                existing.computedAt = Date()
            } else {
                let model = DailyAchievementModel(
                    date: date,
                    subjectId: subjectId,
                    requiredMinutes: requiredMinutes,
                    achievedMinutes: achievedMinutes,
                    achieved: achieved,
                    computedAt: Date()
                )
                context.insert(model)
            }
            try context.save()
        } catch {
            print("[AchievementService] upsertAchievement error: \(error)")
        }
    }

    static func calculateStreak(context: ModelContext, subjectId: UUID?) -> Int {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())

        func achievement(on date: Date) -> DailyAchievementModel? {
            let key = DailyAchievementModel.makeKey(date: date, subjectId: subjectId)
            let descriptor = FetchDescriptor<DailyAchievementModel>(
                predicate: #Predicate { $0.key == key },
                sortBy: []
            )
            return try? context.fetch(descriptor).first
        }

        // 今日達成済みなら今日から、そうでなければ昨日から遡って連続日数を数える
        let startDate: Date = {
            if let rec = achievement(on: todayStart), rec.achieved {
                return todayStart
            } else {
                return calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
            }
        }()

        var date = startDate
        var count = 0
        for _ in 0..<365 {
            guard let rec = achievement(on: date) else { break }
            if rec.achieved {
                count += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: date) else { break }
                date = prev
            } else {
                break
            }
        }
        return count
    }
}
