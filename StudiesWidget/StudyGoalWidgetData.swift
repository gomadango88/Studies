//
// StudyGoalWidgetData.swift
// Studies
//
// Created by takuma on 2025/08/16.
//

import Foundation
import SwiftUI
import WidgetKit
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Studies", category: "widget")

// MARK: - App Group 共有定数
// アプリ本体・ウィジェット・LiveActivity拡張など、複数ターゲットから参照するための共有定数。
// このファイルはStudiesとStudiesLiveActivityExtension双方のターゲットに含まれているため、
// App Group IDのハードコードをここに集約する。

enum AppGroupConstants {
    static let identifier = "group.Kasahara-Takuma.Studies"
}

// MARK: - Widget用のデータ構造

struct WidgetStudyGoalData: Codable {
    let dailyGoal: Int
    let todayMinutes: Int
    let streakDays: Int
    let lastUpdated: Date

    // 目標が未設定（0分）の場合は「達成」とみなさない（アプリ本体の目標達成ベースの判定と統一）
    var isAchieved: Bool {
        dailyGoal > 0 && todayMinutes >= dailyGoal
    }
}

// MARK: - データ共有マネージャー

class WidgetDataManager {
    static let shared = WidgetDataManager()
    private let userDefaults = UserDefaults(suiteName: AppGroupConstants.identifier)
    private let widgetDataKey = "StudyGoalWidgetData"
    
    private init() {}
    
    func saveWidgetData(_ widgetData: WidgetStudyGoalData) {
        guard let userDefaults = userDefaults else {
            logger.error("Failed to initialize UserDefaults with App Groups")
            return
        }

        do {
            let encodedData = try JSONEncoder().encode(widgetData)
            userDefaults.set(encodedData, forKey: widgetDataKey)
        } catch {
            logger.error("Failed to save widget data: \(error)")
        }
    }

    func loadWidgetData() -> WidgetStudyGoalData? {
        guard let userDefaults = userDefaults else {
            logger.error("Failed to initialize UserDefaults with App Groups")
            return nil
        }

        guard let savedData = userDefaults.data(forKey: widgetDataKey) else {
            return nil
        }

        do {
            let decodedData = try JSONDecoder().decode(WidgetStudyGoalData.self, from: savedData)
            return decodedData
        } catch {
            logger.error("Failed to load widget data: \(error)")
            return nil
        }
    }

    func clearWidgetData() {
        guard let userDefaults = userDefaults else {
            logger.error("Failed to initialize UserDefaults")
            return
        }

        userDefaults.removeObject(forKey: widgetDataKey)
    }
}

