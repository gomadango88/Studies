//
//  StudyRecordUseCaseTests.swift
//  StudiesTests
//
//  StudyRecordUseCaseのバリデーションエラー経路のテスト。
//  モックリポジトリ（MockData.swift）を使用する。
//

import Testing
import Foundation
@testable import Studies

struct StudyRecordUseCaseTests {

    // MARK: - createRecord

    @Test func createRecord_zeroDuration_throwsInvalidDuration() async throws {
        let subject = MockData.sampleSubjects[0]
        let subjectRepo = MockSubjectRepository(subjects: [subject])
        let recordRepo = MockStudyRecordRepository()
        let useCase = StudyRecordUseCase(studyRecordRepository: recordRepo, subjectRepository: subjectRepo)

        do {
            _ = try await useCase.createRecord(subjectId: subject.id, duration: 0)
            Issue.record("エラーがスローされるべき")
        } catch let error as StudyRecordUseCaseError {
            guard case .invalidDuration = error else {
                Issue.record("invalidDurationが期待される: \(error)")
                return
            }
        }
    }

    @Test func createRecord_negativeDuration_throwsInvalidDuration() async throws {
        let subject = MockData.sampleSubjects[0]
        let subjectRepo = MockSubjectRepository(subjects: [subject])
        let recordRepo = MockStudyRecordRepository()
        let useCase = StudyRecordUseCase(studyRecordRepository: recordRepo, subjectRepository: subjectRepo)

        do {
            _ = try await useCase.createRecord(subjectId: subject.id, duration: -10)
            Issue.record("エラーがスローされるべき")
        } catch let error as StudyRecordUseCaseError {
            guard case .invalidDuration = error else {
                Issue.record("invalidDurationが期待される: \(error)")
                return
            }
        }
    }

    @Test func createRecord_unknownSubject_throwsSubjectNotFound() async throws {
        let subjectRepo = MockSubjectRepository(subjects: []) // 教材が登録されていない
        let recordRepo = MockStudyRecordRepository()
        let useCase = StudyRecordUseCase(studyRecordRepository: recordRepo, subjectRepository: subjectRepo)

        do {
            _ = try await useCase.createRecord(subjectId: UUID(), duration: 600)
            Issue.record("エラーがスローされるべき")
        } catch let error as StudyRecordUseCaseError {
            guard case .subjectNotFound = error else {
                Issue.record("subjectNotFoundが期待される: \(error)")
                return
            }
        }
    }

    @Test func createRecord_validInput_savesRecord() async throws {
        let subject = MockData.sampleSubjects[0]
        let subjectRepo = MockSubjectRepository(subjects: [subject])
        let recordRepo = MockStudyRecordRepository()
        let useCase = StudyRecordUseCase(studyRecordRepository: recordRepo, subjectRepository: subjectRepo)

        let record = try await useCase.createRecord(subjectId: subject.id, duration: 1800)

        #expect(record.subjectId == subject.id)
        #expect(record.duration == 1800)
        #expect(recordRepo.records.count == 1)
        #expect(recordRepo.saveCallCount == 1)
    }

    // MARK: - updateRecord

    @Test func updateRecord_zeroDuration_throwsInvalidDuration() async throws {
        let subjectRepo = MockSubjectRepository()
        let recordRepo = MockStudyRecordRepository()
        let useCase = StudyRecordUseCase(studyRecordRepository: recordRepo, subjectRepository: subjectRepo)

        let invalidRecord = StudyRecord(subjectId: UUID(), studyDate: Date(), duration: 0)

        await #expect(throws: StudyRecordUseCaseError.self) {
            try await useCase.updateRecord(invalidRecord)
        }
        #expect(recordRepo.updateCallCount == 0)
    }

    @Test func updateRecord_validDuration_updatesRecord() async throws {
        let subject = MockData.sampleSubjects[0]
        let existing = StudyRecord(subjectId: subject.id, studyDate: Date(), duration: 100)
        let recordRepo = MockStudyRecordRepository(records: [existing])
        let subjectRepo = MockSubjectRepository(subjects: [subject])
        let useCase = StudyRecordUseCase(studyRecordRepository: recordRepo, subjectRepository: subjectRepo)

        let updated = StudyRecord(
            id: existing.id,
            subjectId: existing.subjectId,
            studyDate: existing.studyDate,
            duration: 500
        )
        try await useCase.updateRecord(updated)

        #expect(recordRepo.updateCallCount == 1)
        #expect(recordRepo.records.first?.duration == 500)
    }

    // MARK: - getActiveRecords / getArchivedRecords

    @Test func getActiveRecords_filtersOutArchived() async throws {
        let subject = MockData.sampleSubjects[0]
        let active = StudyRecord(subjectId: subject.id, studyDate: Date(), duration: 100)
        let archived = StudyRecord(subjectId: subject.id, studyDate: Date(), duration: 200).archived()
        let recordRepo = MockStudyRecordRepository(records: [active, archived])
        let subjectRepo = MockSubjectRepository(subjects: [subject])
        let useCase = StudyRecordUseCase(studyRecordRepository: recordRepo, subjectRepository: subjectRepo)

        let activeRecords = try await useCase.getActiveRecords()
        let archivedRecords = try await useCase.getArchivedRecords()

        #expect(activeRecords.count == 1)
        #expect(activeRecords.first?.id == active.id)
        #expect(archivedRecords.count == 1)
        #expect(archivedRecords.first?.id == archived.id)
    }
}
