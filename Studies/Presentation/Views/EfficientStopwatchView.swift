//
//  EfficientStopwatchView.swift
//  Studies
//
//  Created by takuma on 2025/08/08.
//

import SwiftUI

struct EfficientStopwatchView: View {
    @Bindable var stopwatchManager: EfficientStopwatchManager
    let subject: Subject
    
    var body: some View {
        VStack(spacing: 20) {
            Text("ストップウォッチ")
                .font(.headline)
                .foregroundColor(.secondary)
            
            // 修正：停止中は静的表示、動作中のみSystemFormatStyleを使用
            VStack(spacing: 8) {
                Text(stopwatchManager.formattedTime)
                    .font(.system(size: 48, weight: .thin, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.primary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .animation(.none, value: stopwatchManager.isRunning)
            }
            .padding(.vertical, 20)
            
            // Apple純正風ボタン
            HStack(spacing: 40) {
                // リセットボタン（左側）
                Button(action: {
                    stopwatchManager.reset()
                }) {
                    Text("リセット")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(stopwatchManager.elapsedTime > 0 ? .primary : .secondary)
                        .frame(width: 80, height: 80)
                        .background(
                            Circle()
                                .fill(Color(.systemGray5))
                        )
                        .glassEffect()
                }
                .disabled(stopwatchManager.elapsedTime == 0)
                
                Spacer()
                
                // 開始/停止ボタン（右側）
                Button(action: {
                    if stopwatchManager.isRunning {
                        stopwatchManager.stop()
                    } else {
                        stopwatchManager.startWithLiveActivity(for: subject)
                    }
                }) {
                    Text(stopwatchManager.isRunning ? "停止" : "開始")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 80, height: 80)
                        .background(
                            Circle()
                                .fill(stopwatchManager.isRunning ?
                                      Color(.systemRed) : Color(.systemGreen))
                        )
                        .glassEffect()
                }
            }
            .padding(.horizontal, 40)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(26)
        .overlay(
            RoundedRectangle(cornerRadius: 26)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }
}

// 統合View（EfficientStopwatchViewをそのまま使用）
struct AdaptiveStopwatchView: View {
    @Bindable var stopwatchManager: EfficientStopwatchManager
    let subject: Subject

    var body: some View {
        EfficientStopwatchView(stopwatchManager: stopwatchManager, subject: subject)
    }
}

