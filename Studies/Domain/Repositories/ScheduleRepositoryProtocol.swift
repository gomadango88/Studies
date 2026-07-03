import Foundation

protocol ScheduleRepositoryProtocol {
    func fetchAll() async throws -> [StudySchedule]
    func upsert(_ schedule: StudySchedule) async throws
    func delete(_ scheduleId: UUID) async throws
    func toggleEnabled(_ id: UUID) async throws
}
