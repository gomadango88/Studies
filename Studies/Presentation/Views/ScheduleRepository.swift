import Foundation
import SwiftData
import SwiftUI

// MARK: - Protocol
protocol ScheduleRepositoryProtocol {
    func fetchAll() async throws -> [StudySchedule]
    func upsert(_ schedule: StudySchedule) async throws
    func delete(_ scheduleId: UUID) async throws
    func toggleEnabled(_ id: UUID) async throws
}

// MARK: - Repository
@MainActor
final class ScheduleRepository: ScheduleRepositoryProtocol {
    private let modelContainer: ModelContainer
    // 孤児SubjectGoalModelの掃除を起動後1回だけ実行するためのフラグ
    private var didCleanUpOrphanGoals = false

    init(modelContainer: ModelContainer) { self.modelContainer = modelContainer }

    func fetchAll() async throws -> [StudySchedule] {
        let ctx = modelContainer.mainContext
        cleanUpOrphanSubjectGoalsIfNeeded(in: ctx)
        let descriptor = FetchDescriptor<StudyScheduleModel>(
            sortBy: [SortDescriptor(\.priority, order: .reverse)]
        )
        let models = try ctx.fetch(descriptor)
        return models.map { $0.toDomain() }
    }

    /// どのスケジュールにも属さないSubjectGoalModel（過去の更新処理バグで発生した孤児レコード）を削除する。
    /// 起動後の初回読み込み時に1回だけ実行する。
    private func cleanUpOrphanSubjectGoalsIfNeeded(in ctx: ModelContext) {
        guard !didCleanUpOrphanGoals else { return }
        didCleanUpOrphanGoals = true

        let descriptor = FetchDescriptor<SubjectGoalModel>(
            predicate: #Predicate { $0.schedule == nil }
        )
        guard let orphans = try? ctx.fetch(descriptor), !orphans.isEmpty else { return }
        orphans.forEach { ctx.delete($0) }
        try? ctx.save()
        print("孤児SubjectGoalModelを削除: \(orphans.count)件")
    }

    func upsert(_ schedule: StudySchedule) async throws {
        let ctx = modelContainer.mainContext
        let descriptor = FetchDescriptor<StudyScheduleModel>(
            predicate: #Predicate { $0.id == schedule.id }
        )
        let existing = try ctx.fetch(descriptor).first

        let model = existing ?? StudyScheduleModel(
            id: schedule.id,
            name: schedule.name,
            dailyGoalMinutes: schedule.dailyGoalMinutes,
            selectedWeekdaysMask: schedule.selectedWeekdays.mask,
            isEnabled: schedule.isEnabled,
            colorRed: schedule.color.red,
            colorGreen: schedule.color.green,
            colorBlue: schedule.color.blue,
            colorAlpha: schedule.color.alpha,
            priority: schedule.priority
        )

        model.name = schedule.name
        model.dailyGoalMinutes = schedule.dailyGoalMinutes
        model.selectedWeekdaysMask = schedule.selectedWeekdays.mask
        model.isEnabled = schedule.isEnabled
        model.colorRed = schedule.color.red
        model.colorGreen = schedule.color.green
        model.colorBlue = schedule.color.blue
        model.colorAlpha = schedule.color.alpha
        model.priority = schedule.priority

        // Replace subject goals
        // 注意: removeAll()だけではリレーションが切れるだけで古いSubjectGoalModelが
        // ストアに孤児として残るため、明示的に削除してから置き換える
        for oldGoal in model.subjectGoals {
            ctx.delete(oldGoal)
        }
        model.subjectGoals = schedule.subjectGoals.map { g in
            let m = SubjectGoalModel(
                id: g.id,
                subjectId: g.subjectId,
                subjectName: g.subjectName,
                subjectColorRed: g.subjectColor.red,
                subjectColorGreen: g.subjectColor.green,
                subjectColorBlue: g.subjectColor.blue,
                subjectColorAlpha: g.subjectColor.alpha,
                goalMinutes: g.goalMinutes,
                isEnabled: g.isEnabled
            )
            m.schedule = model
            return m
        }

        if existing == nil { ctx.insert(model) }
        try ctx.save()
    }

    func delete(_ scheduleId: UUID) async throws {
        let ctx = modelContainer.mainContext
        let descriptor = FetchDescriptor<StudyScheduleModel>(
            predicate: #Predicate { $0.id == scheduleId }
        )
        if let model = try ctx.fetch(descriptor).first {
            ctx.delete(model)
            try ctx.save()
        }
    }

    func toggleEnabled(_ id: UUID) async throws {
        let ctx = modelContainer.mainContext
        let descriptor = FetchDescriptor<StudyScheduleModel>(
            predicate: #Predicate { $0.id == id }
        )
        if let model = try ctx.fetch(descriptor).first {
            model.isEnabled.toggle()
            try ctx.save()
        }
    }
}

// MARK: - Mapping
extension StudyScheduleModel {
    func toDomain() -> StudySchedule {
        StudySchedule(
            id: id,
            name: name,
            dailyGoalMinutes: dailyGoalMinutes,
            selectedWeekdays: selectedWeekdaysMask.toWeekdaySet(),
            isEnabled: isEnabled,
            color: CodableColor(red: colorRed, green: colorGreen, blue: colorBlue, alpha: colorAlpha),
            subjectGoals: subjectGoals.map { $0.toDomain() },
            priority: priority
        )
    }
}

extension SubjectGoalModel {
    func toDomain() -> SubjectGoal {
        SubjectGoal(
            id: id,
            subjectId: subjectId,
            subjectName: subjectName,
            subjectColor: CodableColor(red: subjectColorRed, green: subjectColorGreen, blue: subjectColorBlue, alpha: subjectColorAlpha),
            goalMinutes: goalMinutes,
            isEnabled: isEnabled
        )
    }
}

// MARK: - Weekday mask helpers
extension Set where Element == Weekday {
    var mask: Int { reduce(0) { $0 | (1 << $1.rawValue) } }
}

extension Int {
    func toWeekdaySet() -> Set<Weekday> {
        Set(Weekday.allCases.filter { (self & (1 << $0.rawValue)) != 0 })
    }
}
