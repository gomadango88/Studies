//
//  SubjectSpotlightIndexer.swift
//  Studies
//

import AppIntents
import CoreSpotlight
import Foundation
import os

// 教材をSpotlight検索インデックスに登録する。検索結果からOpenSubjectIntent経由でアプリを開けるようにするための橋渡し
enum SubjectSpotlightIndexer {
    @MainActor
    static func reindexAll() async {
        do {
            let subjects = try await DIContainer.shared.subjectUseCase.getAllSubjects()
            let entities = subjects.map(SubjectEntity.init)
            try await CSSearchableIndex.default().indexAppEntities(entities)
        } catch {
            // Spotlight登録の失敗はアプリの主要機能に影響しないため、警告ログのみで継続する
            Logger.intents.warning("Failed to reindex subjects for Spotlight: \(error)")
        }
    }
}
