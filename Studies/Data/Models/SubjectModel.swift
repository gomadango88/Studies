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
    var isPinned: Bool = false
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        color: Color,
        sortOrder: Int = 0,
        isPinned: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name

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
        self.isPinned = isPinned
        self.createdAt = createdAt
    }

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
    
    func toDomainEntity() -> Subject {
        Subject(
            id: id,
            name: name,
            color: color,
            sortOrder: sortOrder,
            isPinned: isPinned,
            createdAt: createdAt
        )
    }

    static func fromDomainEntity(_ subject: Subject) -> SubjectModel {
        SubjectModel(
            id: subject.id,
            name: subject.name,
            color: subject.color,
            sortOrder: subject.sortOrder,
            isPinned: subject.isPinned,
            createdAt: subject.createdAt
        )
    }
}
