//
//  SubjectRepositoryProtocol.swift
//  Studies
//
//  Created by kasahara takuma on 2025/08/08.
//



import Foundation

protocol SubjectRepositoryProtocol {
    func fetchAll() async throws -> [Subject]
    func save(_ subject: Subject) async throws
    func update(_ subject: Subject) async throws
    func delete(_ subject: Subject) async throws
    func reorderSubjects(_ subjects: [Subject]) async throws
}
