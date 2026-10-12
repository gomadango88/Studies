//
//  SubjectEntity.swift
//  Studies
//

import AppIntents
import Foundation

struct SubjectEntity: AppEntity, IndexedEntity {
    let id: UUID
    let name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Subject"

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    static var defaultQuery = SubjectEntityQuery()

    init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }

    init(_ subject: Subject) {
        self.id = subject.id
        self.name = subject.name
    }
}

struct SubjectEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [SubjectEntity.ID]) async throws -> [SubjectEntity] {
        let subjects = try await DIContainer.shared.subjectUseCase.getAllSubjects()
        return subjects
            .filter { identifiers.contains($0.id) }
            .map(SubjectEntity.init)
    }

    func suggestedEntities() async throws -> [SubjectEntity] {
        let subjects = try await DIContainer.shared.subjectUseCase.getAllSubjects()
        return subjects
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned {
                    return lhs.isPinned && !rhs.isPinned
                }
                return lhs.sortOrder < rhs.sortOrder
            }
            .map(SubjectEntity.init)
    }

    func entities(matching string: String) async throws -> [SubjectEntity] {
        let subjects = try await DIContainer.shared.subjectUseCase.getAllSubjects()
        return subjects
            .filter { $0.name.localizedCaseInsensitiveContains(string) }
            .map(SubjectEntity.init)
    }
}
