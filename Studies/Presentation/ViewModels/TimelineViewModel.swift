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
            // 学習記録と教材データを並行して取得
            async let recordsResult = studyUseCase.getAllRecords()
            async let subjectsResult = subjectUseCase.getAllSubjects()
            
            allRecords = try await recordsResult
            subjects = try await subjectsResult
            
            // 日付ごとにグループ化
            groupRecordsByDate()
            
        } catch {
            errorMessage = "データの読み込みに失敗しました: \(error.localizedDescription)"
            print("Error loading timeline  \(error)")
        }
        
        isLoading = false
    }
    
    // TimelineViewModel.swift に追加
    func deleteRecord(_ record: StudyRecord) async {
        guard let studyRecordUseCase = studyRecordUseCase else {
            print("StudyRecordUseCase is nil")
            return
        }
        
        do {
            try await studyRecordUseCase.deleteRecord(record)
            
            // UIを更新するために記録を再読み込み
            await loadAllRecords()
            
        } catch {
            print("Error deleting record: \(error)")
            // エラーハンドリング（必要に応じてエラーメッセージを表示）
        }
    }

    // 手動追加用の作成メソッド
    func addRecord(subjectId: UUID, studyDate: Date, duration: TimeInterval) async {
        guard let studyRecordUseCase = studyRecordUseCase else {
            print("StudyRecordUseCase is nil")
            return
        }
        do {
            _ = try await studyRecordUseCase.createRecord(
                subjectId: subjectId,
                duration: duration,
                studyDate: studyDate
            )
            // UI更新のため再読み込み
            await loadAllRecords()
        } catch {
            print("Error creating record: \(error)")
        }
    }
    
    private func groupRecordsByDate() {
        let calendar = Calendar.current
        
        // 日付ごとにグループ化（新しい順）
        let grouped = Dictionary(grouping: allRecords) { record in
            calendar.startOfDay(for: record.studyDate)
        }
        
        // 各日付内で時刻順にソート（新しい順）
        groupedRecords = grouped.map { date, records in
            TimelineGroup(
                date: date,
                records: records.sorted { $0.studyDate > $1.studyDate }
            )
        }
        .sorted { $0.date > $1.date } // 日付順（新しい順）
    }
}

// MARK: - Data Models

struct TimelineGroup {
    let date: Date
    let records: [StudyRecord]
}

