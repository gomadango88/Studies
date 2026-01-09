//
//  Subject.swift
//  Studies
//
//  Created by kasahara takuma on 2025/08/08.
//



import Foundation
import SwiftUI

struct Subject: Identifiable, Equatable {
    let id: UUID
    var name: String
    var color: Color
    var sortOrder: Int
    var isPinned: Bool = false
    let createdAt: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        color: Color,
        sortOrder: Int,
        isPinned: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.sortOrder = sortOrder
        self.isPinned = isPinned
        self.createdAt = createdAt
    }
}

// MARK: - Extensions
extension Subject {
    static var mock: Subject {
        Subject(
            name: "数学",
            color: .blue,
            sortOrder: 0
        )
    }
}
