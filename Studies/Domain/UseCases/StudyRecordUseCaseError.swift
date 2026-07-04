//
//  StudyRecordUseCaseError.swift
//  Studies
//
//  Created by kasahara takuma on 2025/08/20.
//

import Foundation

public enum StudyRecordUseCaseError: LocalizedError {
    case invalidDuration
    case subjectNotFound

    public var errorDescription: String? {
        switch self {
        case .invalidDuration:
            return "学習時間は0より大きい値を入力してください"
        case .subjectNotFound:
            return "指定された教材が見つかりません"
        }
    }
}
