//
// LiveActivityState.swift
// Studies
//
// Created by takuma on 2025/08/12.
//

import Foundation
import SwiftUI

// Live Activity専用の軽量データ構造
struct LiveActivityState: Codable {
    let subjectId: UUID
    let subjectName: String
    let subjectColor: String
    let elapsedTime: TimeInterval
    let isRunning: Bool
    let lastUpdateTime: Date
    
    init(subjectId: UUID, subjectName: String, subjectColor: String, elapsedTime: TimeInterval, isRunning: Bool) {
        self.subjectId = subjectId
        self.subjectName = subjectName
        self.subjectColor = subjectColor
        self.elapsedTime = elapsedTime
        self.isRunning = isRunning
        self.lastUpdateTime = Date()
    }
}

// Live Activity用のマネージャー（軽量版）
@MainActor
@Observable
class LiveActivitySessionManager {
    static let shared = LiveActivitySessionManager()
    
    // 🔥 修正：プロパティ名を変更してエラーを回避
    @ObservationIgnored @AppStorage("liveActivitySession")
    private var liveActivitySessionData: Data?
    
    private init() {}
    
    func saveLiveActivityState(subjectId: UUID, subjectName: String, subjectColor: String, elapsedTime: TimeInterval, isRunning: Bool) {
        let state = LiveActivityState(
            subjectId: subjectId,
            subjectName: subjectName,
            subjectColor: subjectColor,
            elapsedTime: elapsedTime,
            isRunning: isRunning
        )
        
        if let encoded = try? JSONEncoder().encode(state) {
            liveActivitySessionData = encoded
            print("✅ Live Activity state saved")
        } else {
            print("❌ Failed to save Live Activity state")
        }
    }
    
    func getLiveActivityState() -> LiveActivityState? {
        guard let data = liveActivitySessionData,
              let state = try? JSONDecoder().decode(LiveActivityState.self, from: data) else {
            print("📭 No Live Activity state found")
            return nil
        }
        
        print("📋 Found Live Activity state: \(state.subjectName)")
        return state
    }
    
    func clearLiveActivityState() {
        print("🗑️ Clearing Live Activity state")
        liveActivitySessionData = nil
    }
    
    func hasActiveState() -> Bool {
        return liveActivitySessionData != nil
    }
}
