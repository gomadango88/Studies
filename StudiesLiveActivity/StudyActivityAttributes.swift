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
        // 経過時間（秒）
        var elapsedTime: TimeInterval
        // 実行状態
        var isRunning: Bool
        // 最終更新時刻
        var lastUpdateTime: Date
        // 今日の合計時間（フォーマット済み文字列）
        var todayTotalTime: String
        
        // 秒を"--"で表示するフォーマット
        var formattedTime: String {
            let totalSeconds = Int(elapsedTime)
            let hours = totalSeconds / 3600
            let minutes = (totalSeconds % 3600) / 60
            if hours > 0 {
                return String(format: "%d:%02d:--", hours, minutes)
            } else {
                return String(format: "%d:--", minutes)
            }
        }
        
        // デバッグ用：完全な時間表示（必要に応じて）
        var fullFormattedTime: String {
            let totalSeconds = Int(elapsedTime)
            let hours = totalSeconds / 3600
            let minutes = (totalSeconds % 3600) / 60
            let seconds = totalSeconds % 60
            if hours > 0 {
                return String(format: "%d:%02d:%02d", hours, minutes, seconds)
            } else {
                return String(format: "%d:%02d", minutes, seconds)
            }
        }
    }
    
    // 教材名
    var subjectName: String
    // 教材の色（Hex形式）
    var subjectColor: String
    // 開始時刻
    var startTime: Date
}

