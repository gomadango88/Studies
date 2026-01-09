//
//  UpdateActivityIntent.swift
//  Studies
//
//  Created by kasahara takuma on 2025/08/12.
//


//
// UpdateActivityIntent.swift
// Studies
//
// Created by takuma on 2025/08/12.
//

import AppIntents
import ActivityKit
import Foundation

@available(iOS 16.0, *)
struct UpdateActivityIntent: AppIntent {
    static var title: LocalizedStringResource = "Update Study Activity"
    static var description = IntentDescription("Updates the live activity with current study progress")
    static var isDiscoverable = false
    
    func perform() async throws -> some IntentResult {
        print("🔄 UpdateActivityIntent triggered")
        
        // StudyActivityManagerに更新を依頼
        //await StudyActivityManager.shared.updateFromBackground()
        
        return .result()
    }
}
