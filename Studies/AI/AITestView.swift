//
//  AITestView.swift
//  Studies
//
//  Created by kasahara takuma on 2025/08/24.
//


//
//  AITestView.swift
//  Studies
//
//  Foundation Models Framework テスト用ビュー
//

import SwiftUI
import FoundationModels

struct AITestView: View {
    @State private var prompt: String = ""
    @State private var response: String = ""
    @State private var isGenerating: Bool = false
    @State private var modelStatus: String = ""
    
    // モデルの参照
    private let model = SystemLanguageModel.default
    
    // 事前定義されたテスト用プロンプト
    private let samplePrompts = [
        "こんにちは！今日はいい天気ですね。",
        "効率的な勉強方法を3つ教えて",
        "短い俳句を作って",
        "プログラミング学習のコツは？",
        "集中力を高める方法は？"
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // モデル状態表示
                modelStatusSection
                
                // プロンプト入力セクション
                promptInputSection
                
                // サンプルプロンプトボタン
                samplePromptsSection
                
                // 生成ボタン
                generateButton
                
                // レスポンス表示エリア
                responseSection
                
                Spacer()
            }
            .padding()
            .navigationTitle("AI テスト")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                checkModelStatus()
            }
        }
    }
    
    // MARK: - UI Components
    
    private var modelStatusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: modelAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(modelAvailable ? .green : .red)
                
                Text("Foundation Models状態")
                    .font(.headline)
                
                Spacer()
            }
            
            Text(modelStatus)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .cornerRadius(12)
    }
    
    private var promptInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("プロンプト入力")
                .font(.headline)
            
            TextField("AIに質問や依頼を入力してください...", text: $prompt, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .lineLimit(3...6)
        }
    }
    
    private var samplePromptsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("サンプルプロンプト")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(samplePrompts, id: \.self) { sample in
                    Button(sample) {
                        prompt = sample
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    .lineLimit(2)
                }
            }
        }
    }
    
    private var generateButton: some View {
        Button(action: {
            Task {
                await generateResponse()
            }
        }) {
            HStack {
                if isGenerating {
                    ProgressView()
                        .scaleEffect(0.8)
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "sparkles")
                }
                
                Text(isGenerating ? "生成中..." : "AI生成開始")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(canGenerate ? Color.blue : Color.gray)
            .cornerRadius(12)
        }
        .disabled(!canGenerate)
    }
    
    private var responseSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("AI レスポンス")
                    .font(.headline)
                
                Spacer()
                
                if !response.isEmpty {
                    Button("クリア") {
                        response = ""
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if response.isEmpty && !isGenerating {
                        VStack(spacing: 8) {
                            Image(systemName: "bubble.left")
                                .font(.system(size: 32))
                                .foregroundColor(.gray)
                            Text("AIからのレスポンスがここに表示されます")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 120)
                    } else {
                        Text(response)
                            .font(.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
            .frame(minHeight: 150)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Computed Properties
    
    private var modelAvailable: Bool {
        model.availability == .available
    }
    
    private var canGenerate: Bool {
        !prompt.isEmpty && !isGenerating && modelAvailable
    }
    
    // MARK: - Functions
    
    private func checkModelStatus() {
        switch model.availability {
        case .available:
            modelStatus = "✅ 利用可能 - AIモデルが使用できます"
            
        case .unavailable(.deviceNotEligible):
            modelStatus = "❌ 非対応デバイス - このデバイスはFoundation Modelsに対応していません"
            
        case .unavailable(.appleIntelligenceNotEnabled):
            modelStatus = "⚠️ 設定が必要 - 設定でApple Intelligenceを有効にしてください"
            
        case .unavailable(.modelNotReady):
            modelStatus = "⏳ 準備中 - AIモデルをダウンロード中または準備中です"
            
        @unknown default:
            modelStatus = "⚠️ 不明な状態 - AIモデルの利用状況を確認できません"
        }
    }
    
    private func generateResponse() async {
        guard modelAvailable else {
            await MainActor.run {
                response = "⚠️ AIモデルが利用できません。設定を確認してください。"
            }
            return
        }
        
        isGenerating = true
        defer { isGenerating = false }
        
        do {
            // カスタム指示付きセッション作成
            let session = LanguageModelSession(
                instructions: """
                あなたは親切で知識豊富なアシスタントです。
                日本語で自然で読みやすい回答を提供してください。
                簡潔でありながら有用な情報を含めてください。
                """
            )
            
            let result = try await session.respond(to: prompt)
            
            await MainActor.run {
                response = result.content
            }
            
            // 成功時のハプティックフィードバック
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
        } catch {
            await MainActor.run {
                response = """
                ❌ エラーが発生しました:
                \(error.localizedDescription)
                
                以下を確認してください：
                • Apple Intelligenceが有効になっているか
                • デバイスがサポートされているか
                • 十分なバッテリー残量があるか
                """
            }
            
            // エラー時のハプティックフィードバック
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.error)
        }
    }
}

// MARK: - Preview

#Preview {
    AITestView()
}
