//
//  EfficientStopwatchView.swift
//  Studies
//
//  Created by takuma on 2025/08/08.
//

import SwiftUI

@available(iOS 18.0, *)
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

// iOS 18未満の場合のフォールバック
struct LegacyStopwatchView: View {
    @Bindable var stopwatchManager: EfficientStopwatchManager
    let subject: Subject
    
    var body: some View {
        VStack(spacing: 20) {
            Text("ストップウォッチ")
                .font(.headline)
                .foregroundColor(.secondary)
            
            // 従来のフォーマット表示
            VStack(spacing: 8) {
                Text(stopwatchManager.formattedTime)
                    .font(.system(size: 48, weight: .thin, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.primary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .padding(.vertical, 20)
            
            // ボタンは同じ
            HStack(spacing: 40) {
                Button(action: {
                    stopwatchManager.reset()
                }) {
                    Text("リセット")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(stopwatchManager.elapsedTime > 0 ? .primary : .secondary)
                        .frame(width: 80, height: 80)
                        .background(Circle().fill(Color(.systemGray5)))
                        .overlay(Circle().stroke(Color(.systemGray4), lineWidth: 2))
                }
                .disabled(stopwatchManager.elapsedTime == 0)
                
                Spacer()
                
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
                        .overlay(
                            Circle()
                                .stroke(stopwatchManager.isRunning ?
                                        Color(.systemRed) : Color(.systemGreen),
                                        lineWidth: 2)
                        )
                }
            }
            .padding(.horizontal, 40)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }
}

// 統合View（iOS版本に応じて自動切り替え）
struct AdaptiveStopwatchView: View {
    @Bindable var stopwatchManager: EfficientStopwatchManager
    let subject: Subject
    
    var body: some View {
        if #available(iOS 18.0, *) {
            EfficientStopwatchView(stopwatchManager: stopwatchManager, subject: subject)
        } else {
            LegacyStopwatchView(stopwatchManager: stopwatchManager, subject: subject)
        }
    }
}

