//
//  StudyAppIntents.swift
//  StudiesLiveActivity
//
//  Created by takuma on 2025/08/08.
//

import Foundation
import AppIntents

// 学習再開Intent
struct ResumeStudyIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "学習を再開"
    static var description = IntentDescription("一時停止中の学習を再開します")
    
    func perform() async throws -> some IntentResult {
        // StudyActivityManagerを通じて学習を再開
        await StudyActivityManager.shared.resumeStudy()
        return .result()
    }
}

// 学習停止Intent
struct StopStudyIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "学習を停止"
    static var description = IntentDescription("現在の学習セッションを終了します")
    
    func perform() async throws -> some IntentResult {
        // StudyActivityManagerを通じて学習を停止
        await StudyActivityManager.shared.stopStudy()
        return .result()
    }
}
