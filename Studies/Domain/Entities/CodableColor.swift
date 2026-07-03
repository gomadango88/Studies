//
// CodableColor.swift
// Studies
//
// Created by kasahara takuma on 2025/08/13.
//

import SwiftUI
import UIKit

struct CodableColor: Codable, Equatable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    init(_ color: Color) {
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.red = Double(r)
        self.green = Double(g)
        self.blue = Double(b)
        self.alpha = Double(a)
    }

    static func == (lhs: CodableColor, rhs: CodableColor) -> Bool {
        let eps = 1e-6
        return abs(lhs.red - rhs.red) < eps &&
               abs(lhs.green - rhs.green) < eps &&
               abs(lhs.blue - rhs.blue) < eps &&
               abs(lhs.alpha - rhs.alpha) < eps
    }
}
