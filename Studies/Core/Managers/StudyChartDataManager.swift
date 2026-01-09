//
//  StudyChartDataManager.swift
//  Studies
//

import Foundation
import SwiftUI

// MARK: - マネージャ (プロトコル定義を削除)
@MainActor
final class StudyChartDataManager {
    private let useCase: StudyChartDataUseCase
    private let calendar = Calendar.current

    init(useCase: StudyChartDataUseCase) {
        self.useCase = useCase
    }

    enum Span: CaseIterable {
        case sevenDays, thirtyDays, twelveMonths
    }

    struct BaseRow: Identifiable, Equatable {
        let id = UUID()
        let subjectId: UUID
        let studyDate: Date
        let duration: TimeInterval
    }

    struct SummarizedRow: Identifiable, Hashable {
        let id = UUID()
        let subjectId: UUID
        let bucketDate: Date
        let duration: TimeInterval
    }

    // 既存のメソッド
    func fetchSummarizedRows(for span: Span, from startDate: Date, to endDate: Date) async throws -> [SummarizedRow] {
        let records = try await useCase.getRecordsForDateRange(from: startDate, to: endDate)
        return processSummarizedRows(records: records, span: span)
    }

    // ← 追加: アクティブなレコードのみ取得
    func fetchActiveSummarizedRows(for span: Span, from startDate: Date, to endDate: Date) async throws -> [SummarizedRow] {
        let activeRecords = try await useCase.getActiveRecordsForDateRange(from: startDate, to: endDate)
        return processSummarizedRows(records: activeRecords, span: span)
    }

    // ← 追加: 共通の集計処理
    private func processSummarizedRows(records: [StudyRecord], span: Span) -> [SummarizedRow] {
        let baseRows = records.map { rec in
            let rounded = (span == .twelveMonths)
                ? calendar.date(from: calendar.dateComponents([.year, .month], from: rec.studyDate))!
                : calendar.startOfDay(for: rec.studyDate)

            return BaseRow(
                subjectId: rec.subjectId,
                studyDate: rounded,
                duration: rec.duration
            )
        }

        struct Key: Hashable {
            let subjectId: UUID
            let bucketDate: Date
        }

        let summed = Dictionary(grouping: baseRows, by: {
            Key(subjectId: $0.subjectId, bucketDate: $0.studyDate)
        }).mapValues { rows in
            rows.reduce(0) { $0 + $1.duration }
        }

        return summed.map { key, total in
            SummarizedRow(subjectId: key.subjectId, bucketDate: key.bucketDate, duration: total)
        }
    }

    // 既存のメソッドも同様に修正
    func fetchSummarizedRows(for span: Span) async throws -> [SummarizedRow] {
        let now = Date()
        let startEnd: (Date, Date) = {
            switch span {
            case .sevenDays:
                let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now))!
                return (start, now)
            case .thirtyDays:
                let start = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: now))!
                return (start, now)
            case .twelveMonths:
                let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
                let start = calendar.date(byAdding: .month, value: -11, to: monthStart)!
                let end = calendar.date(byAdding: .month, value: 1, to: monthStart)!
                return (start, end)
            }
        }()
        
        // ← 修正: アクティブなデータのみ取得
        return try await fetchActiveSummarizedRows(for: span, from: startEnd.0, to: startEnd.1)
    }
}
