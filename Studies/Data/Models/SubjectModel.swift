//
// SubjectModel.swift
// Studies
//
// Created by kasahara takuma on 2025/08/08.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class SubjectModel {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorRed: Double
    var colorGreen: Double
    var colorBlue: Double
    var colorAlpha: Double
    var sortOrder: Int
    var isPinned: Bool = false  // 🔥 追加: ピン留めプロパティ
    var createdAt: Date
    
    // SwiftDataの関係性
    @Relationship(deleteRule: .cascade, inverse: \StudyRecordModel.subject)
    var studyRecords: [StudyRecordModel] = []
    
    init(
        id: UUID = UUID(),
        name: String,
        color: Color,
        sortOrder: Int = 0,
        isPinned: Bool = false,  // 🔥 追加: ピン留めパラメータ
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        
        // ColorをRGBA成分に分解して保存
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        self.colorRed = Double(red)
        self.colorGreen = Double(green)
        self.colorBlue = Double(blue)
        self.colorAlpha = Double(alpha)
        self.sortOrder = sortOrder
        self.isPinned = isPinned  // 🔥 追加: ピン留め状態を設定
        self.createdAt = createdAt
    }
    
    // Colorプロパティ
    var color: Color {
        get {
            Color(
                red: colorRed,
                green: colorGreen,
                blue: colorBlue,
                opacity: colorAlpha
            )
        }
        set {
            let uiColor = UIColor(newValue)
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            
            self.colorRed = Double(red)
            self.colorGreen = Double(green)
            self.colorBlue = Double(blue)
            self.colorAlpha = Double(alpha)
        }
    }
    
    // 🔥 修正: isPinnedを含めたDomain層のSubjectエンティティに変換
    func toDomainEntity() -> Subject {
        Subject(
            id: id,
            name: name,
            color: color,
            sortOrder: sortOrder,
            isPinned: isPinned,  // 🔥 追加: ピン留め状態を含める
            createdAt: createdAt
        )
    }
    
    // 🔥 修正: isPinnedを含めたDomain層のSubjectエンティティから作成
    static func fromDomainEntity(_ subject: Subject) -> SubjectModel {
        SubjectModel(
            id: subject.id,
            name: subject.name,
            color: subject.color,
            sortOrder: subject.sortOrder,
            isPinned: subject.isPinned,  // 🔥 追加: ピン留め状態を含める
            createdAt: subject.createdAt
        )
    }
}
