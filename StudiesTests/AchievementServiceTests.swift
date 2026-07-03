//
//  AchievementServiceTests.swift
//  StudiesTests
//
//  AchievementService.calculateStreak / upsertAchievement のテスト。
//  インメモリModelContainerにDailyAchievementModelを投入して検証する。
//

import Testing
import SwiftData
import Foundation
@testable import Studies

@MainActor
struct AchievementServiceTests {

    // DIContainerと同じ5モデルでインメモリコンテナを作成する
    private func makeInMemoryContext() -> ModelContext {
        let schema = Schema([
            SubjectModel.self,
            StudyRecordModel.self,
            DailyAchievementModel.self,
            StudyScheduleModel.self,
            SubjectGoalModel.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    private func daysAgo(_ n: Int, from base: Date = Date()) -> Date {
        Calendar.current.date(byAdding: .day, value: -n, to: base)!
    }

    // MARK: - calculateStreak

    @Test func calculateStreak_noRecords_returnsZero() {
        let context = makeInMemoryContext()
        let streak = AchievementService.calculateStreak(context: context, subjectId: nil)
        #expect(streak == 0)
    }

    @Test func calculateStreak_todayOnlyAchieved_returnsOne() {
        let context = makeInMemoryContext()
        AchievementService.upsertAchievement(
            context: context,
            date: Date(),
            subjectId: nil,
            requiredMinutes: 30,
            achievedMinutes: 30
        )

        let streak = AchievementService.calculateStreak(context: context, subjectId: nil)
        #expect(streak == 1)
    }

    @Test func calculateStreak_todayAndYesterdayAchieved_returnsTwo() {
        let context = makeInMemoryContext()
        AchievementService.upsertAchievement(
            context: context,
            date: Date(),
            subjectId: nil,
            requiredMinutes: 30,
            achievedMinutes: 40
        )
        AchievementService.upsertAchievement(
            context: context,
            date: daysAgo(1),
            subjectId: nil,
            requiredMinutes: 30,
            achievedMinutes: 30
        )

        let streak = AchievementService.calculateStreak(context: context, subjectId: nil)
        #expect(streak == 2)
    }

    @Test func calculateStreak_brokenByUnachievedPastDay_resets() {
        let context = makeInMemoryContext()
        // 今日は達成
        AchievementService.upsertAchievement(
            context: context,
            date: Date(),
            subjectId: nil,
            requiredMinutes: 30,
            achievedMinutes: 30
        )
        // 昨日は目標未達成 → ここで途切れる
        AchievementService.upsertAchievement(
            context: context,
            date: daysAgo(1),
            subjectId: nil,
            requiredMinutes: 30,
            achievedMinutes: 10
        )
        // 一昨日は達成（途切れているのでカウントされない）
        AchievementService.upsertAchievement(
            context: context,
            date: daysAgo(2),
            subjectId: nil,
            requiredMinutes: 30,
            achievedMinutes: 30
        )

        let streak = AchievementService.calculateStreak(context: context, subjectId: nil)
        #expect(streak == 1)
    }

    @Test func calculateStreak_skipsDayWithoutGoal() {
        let context = makeInMemoryContext()
        // 今日達成
        AchievementService.upsertAchievement(
            context: context,
            date: Date(),
            subjectId: nil,
            requiredMinutes: 30,
            achievedMinutes: 30
        )
        // 昨日は目標なし（requiredMinutes = 0）→ スキップして続きを数える
        AchievementService.upsertAchievement(
            context: context,
            date: daysAgo(1),
            subjectId: nil,
            requiredMinutes: 0,
            achievedMinutes: 0
        )
        // 一昨日は達成
        AchievementService.upsertAchievement(
            context: context,
            date: daysAgo(2),
            subjectId: nil,
            requiredMinutes: 30,
            achievedMinutes: 45
        )

        let streak = AchievementService.calculateStreak(context: context, subjectId: nil)
        #expect(streak == 2)
    }

    @Test func calculateStreak_todayUnachieved_skipsToYesterday() {
        let context = makeInMemoryContext()
        // 今日は目標未達成（今日はスキップされ、途切れの判定にならない）
        AchievementService.upsertAchievement(
            context: context,
            date: Date(),
            subjectId: nil,
            requiredMinutes: 30,
            achievedMinutes: 5
        )
        // 昨日は達成
        AchievementService.upsertAchievement(
            context: context,
            date: daysAgo(1),
            subjectId: nil,
            requiredMinutes: 30,
            achievedMinutes: 30
        )

        let streak = AchievementService.calculateStreak(context: context, subjectId: nil)
        #expect(streak == 1)
    }

    @Test func calculateStreak_filtersBySubjectId() {
        let context = makeInMemoryContext()
        let subjectA = UUID()
        let subjectB = UUID()

        // subjectAは今日・昨日達成
        AchievementService.upsertAchievement(
            context: context, date: Date(), subjectId: subjectA,
            requiredMinutes: 30, achievedMinutes: 30
        )
        AchievementService.upsertAchievement(
            context: context, date: daysAgo(1), subjectId: subjectA,
            requiredMinutes: 30, achievedMinutes: 30
        )

        // subjectBは今日のみ達成
        AchievementService.upsertAchievement(
            context: context, date: Date(), subjectId: subjectB,
            requiredMinutes: 20, achievedMinutes: 20
        )

        let streakA = AchievementService.calculateStreak(context: context, subjectId: subjectA)
        let streakB = AchievementService.calculateStreak(context: context, subjectId: subjectB)

        #expect(streakA == 2)
        #expect(streakB == 1)
    }

    // MARK: - upsertAchievement

    @Test func upsertAchievement_sameDayTwice_doesNotDuplicate() throws {
        let context = makeInMemoryContext()
        let date = Date()

        AchievementService.upsertAchievement(
            context: context, date: date, subjectId: nil,
            requiredMinutes: 30, achievedMinutes: 10
        )
        AchievementService.upsertAchievement(
            context: context, date: date, subjectId: nil,
            requiredMinutes: 30, achievedMinutes: 30
        )

        let descriptor = FetchDescriptor<DailyAchievementModel>()
        let all = try context.fetch(descriptor)
        #expect(all.count == 1)
        #expect(all.first?.achievedMinutes == 30)
        #expect(all.first?.achieved == true)
    }

    @Test func upsertAchievement_updatesExistingValues() throws {
        let context = makeInMemoryContext()
        let date = Date()

        AchievementService.upsertAchievement(
            context: context, date: date, subjectId: nil,
            requiredMinutes: 60, achievedMinutes: 20
        )

        let descriptorBefore = FetchDescriptor<DailyAchievementModel>()
        let before = try context.fetch(descriptorBefore)
        #expect(before.count == 1)
        #expect(before.first?.achieved == false)

        AchievementService.upsertAchievement(
            context: context, date: date, subjectId: nil,
            requiredMinutes: 60, achievedMinutes: 60
        )

        let descriptorAfter = FetchDescriptor<DailyAchievementModel>()
        let after = try context.fetch(descriptorAfter)
        #expect(after.count == 1)
        #expect(after.first?.achievedMinutes == 60)
        #expect(after.first?.achieved == true)
    }

    @Test func upsertAchievement_noGoal_notAchieved() throws {
        let context = makeInMemoryContext()

        AchievementService.upsertAchievement(
            context: context, date: Date(), subjectId: nil,
            requiredMinutes: 0, achievedMinutes: 50
        )

        let descriptor = FetchDescriptor<DailyAchievementModel>()
        let all = try context.fetch(descriptor)
        #expect(all.count == 1)
        // requiredMinutes <= 0 の場合は達成扱いにならない
        #expect(all.first?.achieved == false)
    }

    @Test func upsertAchievement_differentSubjectsSameDay_createSeparateRecords() throws {
        let context = makeInMemoryContext()
        let date = Date()
        let subjectA = UUID()
        let subjectB = UUID()

        AchievementService.upsertAchievement(
            context: context, date: date, subjectId: subjectA,
            requiredMinutes: 30, achievedMinutes: 30
        )
        AchievementService.upsertAchievement(
            context: context, date: date, subjectId: subjectB,
            requiredMinutes: 30, achievedMinutes: 10
        )
        AchievementService.upsertAchievement(
            context: context, date: date, subjectId: nil,
            requiredMinutes: 30, achievedMinutes: 30
        )

        let descriptor = FetchDescriptor<DailyAchievementModel>()
        let all = try context.fetch(descriptor)
        #expect(all.count == 3)
    }
}
