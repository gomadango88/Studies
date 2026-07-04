//
// StudyActivityAttributes.swift
// Studies
//
// Created by takuma on 2025/08/08.
//

import Foundation
import ActivityKit

struct StudyActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // 実行中の経過時間の基準となる開始時刻（elapsed = (pausedDate ?? now) - startDate）
        var startDate: Date
        // 一時停止した時刻（実行中はnil）。Text(timerInterval:)を使わない静的表示に使う
        var pausedDate: Date?
        var isRunning: Bool

        // 一時停止中の固定経過時間
        var pausedElapsedTime: TimeInterval {
            guard let pausedDate else { return 0 }
            return max(0, pausedDate.timeIntervalSince(startDate))
        }

        // 一時停止中に表示する静的な時間文字列
        var pausedFormattedTime: String {
            let totalSeconds = Int(pausedElapsedTime)
            let hours = totalSeconds / 3600
            let minutes = (totalSeconds % 3600) / 60
            let seconds = totalSeconds % 60
            if hours > 0 {
                return String(format: "%d:%02d:%02d", hours, minutes, seconds)
            } else {
                return String(format: "%d:%02d", minutes, seconds)
            }
        }

        // Text(timerInterval:)に渡す範囲の終端（十分先の未来を設定）
        var timerRangeEnd: Date {
            startDate.addingTimeInterval(60 * 60 * 24)
        }
    }

    // 教材ID（再開時に同じ教材のアクティビティか判定するために使う）
    var subjectId: UUID
    var subjectName: String
    // 教材の色（Hex形式）
    var subjectColor: String
    var startTime: Date
}
