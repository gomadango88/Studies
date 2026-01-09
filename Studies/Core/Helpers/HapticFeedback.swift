//
//  HapticFeedback.swift
//  Studies
//
//  Created by kasahara takuma on 2025/08/08.
//


//
//  HapticFeedback.swift
//  Studies
//
//  Created by takuma on 2025/08/08.
//

import UIKit

@MainActor
final class HapticFeedback {
    
    // MARK: - Impact Feedback
    
    /// 軽い触覚フィードバック
    static func light() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    /// 中程度の触覚フィードバック
    static func medium() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    /// 強い触覚フィードバック
    static func heavy() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
    }
    
    /// 硬質な触覚フィードバック（iOS 13+）
    static func rigid() {
        if #available(iOS 13.0, *) {
            let impactFeedback = UIImpactFeedbackGenerator(style: .rigid)
            impactFeedback.impactOccurred()
        } else {
            // iOS 13未満では代替として heavy を使用
            heavy()
        }
    }
    
    /// ソフトな触覚フィードバック（iOS 13+）
    static func soft() {
        if #available(iOS 13.0, *) {
            let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
            impactFeedback.impactOccurred()
        } else {
            // iOS 13未満では代替として light を使用
            light()
        }
    }
    
    // MARK: - Notification Feedback
    
    /// 成功の触覚フィードバック
    static func success() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
    }
    
    /// 警告の触覚フィードバック
    static func warning() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.warning)
    }
    
    /// エラーの触覚フィードバック
    static func error() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.error)
    }
    
    // MARK: - Selection Feedback
    
    /// 選択の触覚フィードバック
    static func selection() {
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()
    }
}
