//
// ScheduleViewModel.swift
// Studies
//
// Created by kasahara takuma on 2025/08/13.
//

import Foundation
import SwiftUI
import os

@MainActor
@Observable
class ScheduleViewModel {
    private let container: DIContainer
    private var repository: ScheduleRepositoryProtocol
    var schedules: [StudySchedule] = []
    var subjects: [Subject] = []

    init(container: DIContainer) {
        self.container = container
        self.repository = container.scheduleRepository
    }

    func loadData() async {
        do {
            subjects = try await container.subjectUseCase.getAllSubjects()
            await loadSchedules()
        } catch {
            Logger.ui.error("データ読み込みエラー: \(error)")
        }
    }

    private func loadSchedules() async {
        await migrateFromUserDefaultsIfNeeded()
        do {
            schedules = try await repository.fetchAll()
        } catch {
            Logger.ui.error("スケジュール読み込みエラー: \(error)")
            schedules = []
        }
    }

    private func saveSchedules() { /* SwiftData manages persistence */ }

    // スケジュール保存時にウィジェット更新
    func saveSchedule(_ schedule: StudySchedule) {
        Task {
            do {
                try await repository.upsert(schedule)
                schedules = try await repository.fetchAll()
                await updateWidgetAfterScheduleChange()
            } catch {
                Logger.ui.error("スケジュール保存エラー: \(error)")
            }
        }
    }

    // スケジュール削除時にウィジェット更新
    func deleteSchedule(atOffsets offsets: IndexSet) {
        let ids = offsets.compactMap { schedules[$0].id }
        Task {
            do {
                for id in ids {
                    try await repository.delete(id)
                }
                schedules = try await repository.fetchAll()
                await updateWidgetAfterScheduleChange()
            } catch {
                Logger.ui.error("スケジュール削除エラー: \(error)")
            }
        }
    }

    // スケジュール削除時にウィジェット更新
    func deleteSchedule(at index: Int) {
        guard index < schedules.count else { return }
        let id = schedules[index].id
        Task {
            do {
                try await repository.delete(id)
                schedules = try await repository.fetchAll()
                await updateWidgetAfterScheduleChange()
            } catch {
                Logger.ui.error("スケジュール削除エラー: \(error)")
            }
        }
    }

    // スケジュール削除時にウィジェット更新
    func deleteSchedule(withId id: UUID) {
        Task {
            do {
                try await repository.delete(id)
                schedules = try await repository.fetchAll()
                await updateWidgetAfterScheduleChange()
            } catch {
                Logger.ui.error("スケジュール削除エラー: \(error)")
            }
        }
    }

    // スケジュール有効化/無効化時にウィジェット更新
    func toggleSchedule(withId id: UUID) {
        Task {
            do {
                try await repository.toggleEnabled(id)
                schedules = try await repository.fetchAll()
                await updateWidgetAfterScheduleChange()
            } catch {
                Logger.ui.error("スケジュール更新エラー: \(error)")
            }
        }
    }

    func getTodayActiveSchedule() -> StudySchedule? {
        let today = Calendar.current.component(.weekday, from: Date()) - 1
        let weekday = Weekday(rawValue: today) ?? .sunday

        return schedules
            .filter { $0.isEnabled && $0.selectedWeekdays.contains(weekday) }
            .max { $0.priority < $1.priority }
    }

    func getHighestPrioritySchedule(for weekday: Weekday) -> StudySchedule? {
        return schedules
            .filter { $0.isEnabled && $0.selectedWeekdays.contains(weekday) }
            .max { $0.priority < $1.priority }
    }

    // スケジュール変更後のウィジェット更新
    private func updateWidgetAfterScheduleChange() async {
        await WidgetUpdateService.update(using: container)
    }

    private func migrateFromUserDefaultsIfNeeded() async {
        let migratedKey = "StudySchedulesMigrated"
        if UserDefaults.standard.bool(forKey: migratedKey) { return }

        do {
            let existing = try await repository.fetchAll()
            if !existing.isEmpty {
                UserDefaults.standard.set(true, forKey: migratedKey)
                return
            }
        } catch {
            Logger.data.error("スケジュール移行前チェックエラー: \(error)")
        }

        guard let data = UserDefaults.standard.data(forKey: "StudySchedules") else {
            UserDefaults.standard.set(true, forKey: migratedKey)
            return
        }
        do {
            let old = try JSONDecoder().decode([StudySchedule].self, from: data)
            for s in old {
                try await repository.upsert(s)
            }
            UserDefaults.standard.set(true, forKey: migratedKey)
            // Optionally clear old data
            // UserDefaults.standard.removeObject(forKey: "StudySchedules")
        } catch {
            Logger.data.error("旧スケジュールの移行失敗: \(error)")
            UserDefaults.standard.set(true, forKey: migratedKey)
        }
    }
}
