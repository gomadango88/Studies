//
//  AchievementService.swift
//  Studies
//

import Foundation
import SwiftData
import os

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
        // 目標が設定されている日(requiredMinutes > 0)のみ達成になり得る
        let achieved = requiredMinutes > 0 && achievedMinutes >= requiredMinutes
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
            Logger.data.error("upsertAchievement error: \(error)")
        }
    }

    // 連続達成日数（目標達成ベース）を計算する
    // - 目標(requiredMinutes > 0)を達成した日だけがカウントされる
    // - 目標なしの日(requiredMinutes <= 0 またはレコードなし)はスキップして続きを数える
    // - 目標があるのに未達成の過去日でストリークは途切れる
    // - 今日がまだ未達成の場合は今日をスキップして昨日から数える
    static func calculateStreak(context: ModelContext, subjectId: UUID?) -> Int {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())

        let descriptor = FetchDescriptor<DailyAchievementModel>(
            predicate: #Predicate { $0.subjectId == subjectId },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        let records = (try? context.fetch(descriptor)) ?? []
        guard !records.isEmpty else { return 0 }

        var recordsByDay: [Date: DailyAchievementModel] = [:]
        for record in records {
            recordsByDay[calendar.startOfDay(for: record.date)] = record
        }
        let earliestDate = calendar.startOfDay(for: records.first?.date ?? todayStart)

        // 保存済みのachievedフラグは旧仕様で書かれた可能性があるため、
        // requiredMinutes と achievedMinutes から動的に判定する
        func isAchieved(_ record: DailyAchievementModel) -> Bool {
            record.requiredMinutes > 0 && record.achievedMinutes >= record.requiredMinutes
        }

        var count = 0
        var date = todayStart
        for _ in 0..<365 {
            if date < earliestDate { break }
            if let record = recordsByDay[date] {
                if isAchieved(record) {
                    count += 1
                } else if record.requiredMinutes > 0 && date != todayStart {
                    // 目標があるのに未達成の過去日で途切れる
                    // (今日はまだ達成できる可能性があるためスキップ)
                    break
                }
                // 目標なしの日はスキップして続きを数える
            }
            // レコードがない日は目標がなかった日として扱いスキップ
            guard let previous = calendar.date(byAdding: .day, value: -1, to: date) else { break }
            date = previous
        }
        return count
    }
}
