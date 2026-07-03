//
// StudyGoalWidgetData.swift
// Studies
//
// Created by takuma on 2025/08/16.
//

import Foundation
import SwiftUI
import WidgetKit

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
            print("Failed to initialize UserDefaults with App Groups")
            return
        }
        
        do {
            let encodedData = try JSONEncoder().encode(widgetData)
            userDefaults.set(encodedData, forKey: widgetDataKey)
            print("Widget data saved successfully")
        } catch {
            print("Failed to save widget data: \(error)")
        }
    }
    
    func loadWidgetData() -> WidgetStudyGoalData? {
        guard let userDefaults = userDefaults else {
            print("Failed to initialize UserDefaults with App Groups")
            return nil
        }
        
        guard let savedData = userDefaults.data(forKey: widgetDataKey) else {
            print("No data found for key: \(widgetDataKey)")
            return nil
        }
        
        do {
            let decodedData = try JSONDecoder().decode(WidgetStudyGoalData.self, from: savedData)
            return decodedData
        } catch {
            print("Failed to load widget data: \(error)")
            return nil
        }
    }
    
    // デバッグ用メソッド
    func testConnection() -> Bool {
        print("Testing App Groups connection...")
        
        guard let userDefaults = userDefaults else {
            print("UserDefaults initialization failed")
            return false
        }
        
        let testKey = "test_connection"
        let testValue = "connection_success_\(Date().timeIntervalSince1970)"
        
        userDefaults.set(testValue, forKey: testKey)

        let retrievedValue = userDefaults.string(forKey: testKey)
        let isSuccess = retrievedValue == testValue
        
        print("Test result: \(isSuccess ? "SUCCESS" : "FAILED")")
        print("Sent: \(testValue)")
        print("Retrieved: \(retrievedValue ?? "nil")")
        
        userDefaults.removeObject(forKey: testKey)
        return isSuccess
    }
    
    func clearWidgetData() {
        print("Clearing widget data...")
        
        guard let userDefaults = userDefaults else {
            print("Failed to initialize UserDefaults")
            return
        }
        
        userDefaults.removeObject(forKey: widgetDataKey)
        print("Widget data cleared")
    }
    
    func debugAllData() {
        print("Debug: All App Groups data...")
        
        guard let userDefaults = userDefaults else {
            print("UserDefaults not available")
            return
        }
        
        let allKeys = userDefaults.dictionaryRepresentation().keys
        print("Available keys in App Groups: \(Array(allKeys))")
        
        for key in allKeys {
            let value = userDefaults.object(forKey: key)
            print("Key: \(key), Value type: \(type(of: value))")
        }
    }
}

