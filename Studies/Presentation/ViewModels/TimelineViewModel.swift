//
//  TimelineViewModel.swift
//  Studies
//
//  Created by kasahara takuma on 2025/08/08.
//


//
//  TimelineViewModel.swift
//  Studies
//
//  Created by takuma on 2025/08/08.
//

import Foundation
import SwiftUI
import os

@MainActor
@Observable
class TimelineViewModel {
    private var diContainer: DIContainer?
    private var studyRecordUseCase: StudyRecordUseCaseProtocol? {
        diContainer?.studyRecordUseCase
    }
    private var subjectUseCase: SubjectUseCaseProtocol? {
        diContainer?.subjectUseCase
    }
    
    var allRecords: [StudyRecord] = []
    var subjects: [Subject] = []
    var groupedRecords: [TimelineGroup] = []
    var isLoading = false
    var errorMessage: String?
    
    func setContainer(_ container: DIContainer) {
        self.diContainer = container
    }
    
    func loadAllRecords() async {
        guard let studyUseCase = studyRecordUseCase,
              let subjectUseCase = subjectUseCase else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            async let recordsResult = studyUseCase.getAllRecords()
            async let subjectsResult = subjectUseCase.getAllSubjects()

            allRecords = try await recordsResult
            subjects = try await subjectsResult

            groupRecordsByDate()
            
        } catch {
            errorMessage = String(localized: "データの読み込みに失敗しました: \(error.localizedDescription)")
            Logger.ui.error("Error loading timeline: \(error)")
        }
        
        isLoading = false
    }
    
    func deleteRecord(_ record: StudyRecord) async {
        guard let studyRecordUseCase = studyRecordUseCase else {
            return
        }

        do {
            try await studyRecordUseCase.deleteRecord(record)

            await loadAllRecords()

        } catch {
            Logger.ui.error("Error deleting record: \(error)")
        }
    }

    func addRecord(subjectId: UUID, studyDate: Date, duration: TimeInterval) async {
        guard let studyRecordUseCase = studyRecordUseCase else {
            return
        }
        do {
            _ = try await studyRecordUseCase.createRecord(
                subjectId: subjectId,
                duration: duration,
                studyDate: studyDate
            )
            await loadAllRecords()
        } catch {
            Logger.ui.error("Error creating record: \(error)")
        }
    }
    
    private func groupRecordsByDate() {
        let calendar = Calendar.current

        let grouped = Dictionary(grouping: allRecords) { record in
            calendar.startOfDay(for: record.studyDate)
        }

        groupedRecords = grouped.map { date, records in
            TimelineGroup(
                date: date,
                records: records.sorted { $0.studyDate > $1.studyDate }
            )
        }
        .sorted { $0.date > $1.date }
    }
}

// MARK: - Data Models

struct TimelineGroup {
    let date: Date
    let records: [StudyRecord]
}

