//
//  AIStudyAdviceView.swift
//  Studies
//
//  統計ビュー用AI学習アドバイス機能
//

import SwiftUI
import FoundationModels
import Combine

// MARK: - ViewModel
@MainActor
class AIStudyAdviceViewModel: ObservableObject {
    @Published var advice: String = ""
    @Published var isLoading: Bool = false
    @Published var hasGeneratedAdvice: Bool = false
    
    private let model = SystemLanguageModel.default
    
    var isAvailable: Bool {
        model.availability == .available
    }
    
    func generateStudyAdvice() async {
        guard isAvailable else { return }
        
        isLoading = true
        advice = ""
        
        do {
            let session = LanguageModelSession(
                instructions: """
                あなたは学習効率向上の専門家です。
                簡潔で実用的なアドバイスを日本語で提供してください。
                ポジティブで励ましになるトーンを心がけてください。
                """
            )
            
            let prompt = """
            学習記録アプリの統計データから、効率的な学習方法について
            以下の観点でアドバイスを生成してください：
            
            1. 継続的な学習習慣の作り方
            2. 学習時間の効果的な活用法
            3. モチベーション維持のコツ
            4. 学習効率を上げる具体的な方法
            
            300文字程度で簡潔にまとめてください。
            """
            
            let response = try await session.respond(to: prompt)
            
            advice = response.content
            hasGeneratedAdvice = true
            
        } catch {
            advice = """
            ❌ アドバイス生成中にエラーが発生しました。
            
            以下を確認してください：
            • Apple Intelligenceが有効になっているか
            • デバイスが対応しているか
            • 十分なバッテリー残量があるか
            
            エラー詳細: \(error.localizedDescription)
            """
        }
        
        isLoading = false
    }
    
    func clearAdvice() {
        advice = ""
        hasGeneratedAdvice = false
    }
}

// MARK: - View
struct AIStudyAdviceView: View {
    @StateObject private var viewModel = AIStudyAdviceViewModel()
    
    var body: some View {
        Group {
            if viewModel.isAvailable {
                VStack(alignment: .leading, spacing: 16) {
                    // ヘッダー
                    aiAdviceHeader
                    
                    // コンテンツエリア
                    aiAdviceContent
                    
                    // アクションボタン
                    aiAdviceActions
                }
                .padding()
                .background(Color(.systemGroupedBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 3, y: 2)
            } else {
                EmptyView()
            }
        }
    }
    
    // MARK: - UI Components
    
    private var aiAdviceHeader: some View {
        HStack {
            Image(systemName: "brain.head.profile")
                .font(.title2)
                .foregroundColor(.blue)
            
            Text("AI学習アドバイス")
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
            
            if viewModel.hasGeneratedAdvice {
                Button("クリア") {
                    viewModel.clearAdvice()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
    }
    
    private var aiAdviceContent: some View {
        Group {
            if viewModel.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    
                    Text("学習パターンを分析中...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 100)
                
            } else if !viewModel.advice.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(viewModel.advice)
                            .font(.body)
                            .lineLimit(nil)
                            .textSelection(.enabled)
                        
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                            Text("AI生成されたアドバイス")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                    .padding()
                }
                .frame(maxHeight: 200)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(8)
                
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 32))
                        .foregroundColor(.blue.opacity(0.6))
                    
                    VStack(spacing: 4) {
                        Text("学習データを分析")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("AIがあなたの学習パターンを分析し、\n効果的な学習方法をアドバイスします")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 100)
            }
        }
    }
    
    private var aiAdviceActions: some View {
        Button(action: {
            Task {
                await viewModel.generateStudyAdvice()
            }
        }) {
            HStack {
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "sparkles")
                }
                
                Text(viewModel.hasGeneratedAdvice ? "再分析" : "アドバイス生成")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(viewModel.isLoading ? Color.gray : Color.blue)
            .cornerRadius(10)
        }
        .disabled(viewModel.isLoading)
    }
}

// MARK: - Preview
#Preview {
    VStack {
        AIStudyAdviceView()
        Spacer()
    }
    .padding()
    .background(Color(.systemBackground))
}
