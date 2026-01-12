//
// StudySessionState.swift
// Studies
//
// Created by takuma on 2025/08/12.
//

import Foundation
import SwiftUI

struct StudySessionState: Codable {
    let subjectId: UUID
    let subjectName: String
    let subjectColor: String
    let startTime: Date
    let elapsedTime: TimeInterval
    let accumulatedTime: TimeInterval
    let isRunning: Bool
    let lastUpdateTime: Date
    
    init(subjectId: UUID, subjectName: String, subjectColor: String, startTime: Date, elapsedTime: TimeInterval, accumulatedTime: TimeInterval, isRunning: Bool) {
        self.subjectId = subjectId
        self.subjectName = subjectName
        self.subjectColor = subjectColor
        self.startTime = startTime
        self.elapsedTime = elapsedTime
        self.accumulatedTime = accumulatedTime
        self.isRunning = isRunning
        self.lastUpdateTime = Date()
    }
}

@MainActor
@Observable
class StudySessionManager {
    static let shared = StudySessionManager()
    
    // @ObservationIgnoredを追加してエラーを解決
    @ObservationIgnored @AppStorage("activeStudySession")
    private var activeStudySessionData: Data?
    
    private init() {}
    
    func saveActiveSession(subject: Subject, stopwatchManager: EfficientStopwatchManager) {
        print("Saving active study session for: \(subject.name)")
        
        let colorHex = "#0066CC" // 簡易色
        
        let state = StudySessionState(
            subjectId: subject.id,
            subjectName: subject.name,
            subjectColor: colorHex,
            startTime: stopwatchManager.stopwatchStartDate ?? Date(),
            elapsedTime: stopwatchManager.elapsedTime,
            accumulatedTime: stopwatchManager.accumulatedTime,
            isRunning: stopwatchManager.isRunning
        )
        
        if let encoded = try? JSONEncoder().encode(state) {
            activeStudySessionData = encoded
            print("Study session state saved")
        } else {
            print("Failed to encode study session state")
        }
    }
    
    func getActiveSession() -> StudySessionState? {
        guard let data = activeStudySessionData,
              let state = try? JSONDecoder().decode(StudySessionState.self, from: data) else {
            print("No active study session found")
            return nil
        }
        
        print("Found active study session: \(state.subjectName)")
        return state
    }
    
    func clearActiveSession() {
        print("Clearing active study session")
        activeStudySessionData = nil
    }
    
    func hasActiveSession() -> Bool {
        return activeStudySessionData != nil
    }
}

