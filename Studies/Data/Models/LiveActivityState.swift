//
// LiveActivityState.swift
// Studies
//
// Created by takuma on 2025/08/12.
//

import Foundation
import SwiftUI
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Studies", category: "liveActivity")

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

@MainActor
@Observable
class LiveActivitySessionManager {
    static let shared = LiveActivitySessionManager()

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
        } else {
            logger.error("Failed to save Live Activity state")
        }
    }

    func getLiveActivityState() -> LiveActivityState? {
        guard let data = liveActivitySessionData,
              let state = try? JSONDecoder().decode(LiveActivityState.self, from: data) else {
            return nil
        }

        return state
    }

    func clearLiveActivityState() {
        liveActivitySessionData = nil
    }
    
    func hasActiveState() -> Bool {
        return liveActivitySessionData != nil
    }
}
