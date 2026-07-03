//
// StudySessionView.swift
// Studies
//
// Created by takuma on 2025/08/08.
//

import SwiftUI

struct StudySessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DIContainer.self) private var diContainer
    @State private var viewModel: StudySessionViewModel

    // アラート表示用の状態管理
    @State private var showingCloseConfirmation = false
    @State private var hasPresentedAlert = false

    // 新しい効率的ストップウォッチマネージャー
    @State private var efficientStopwatchManager = EfficientStopwatchManager()
    
    let subject: Subject
    
    init(subject: Subject) {
        self.subject = subject
        self._viewModel = State(wrappedValue: StudySessionViewModel(subject: subject))
    }
    
    var body: some View {
        
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    subjectHeader
                    
                    timeInputSection
                    
                    efficientStopwatchSection
                    
                    saveButton
                    
                    Color.clear.frame(height: 20)
                }
                .padding()
            }
            .navigationTitle("学習記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる", systemImage:"xmark", action: {
                        handleCloseAction()
                    })
                        .labelStyle(.iconOnly)
                        .accessibilityLabel("閉じる")
                }
            }
        }
        // スワイプでの閉じる動作を制御
        .presentationDetents([.large])
        .presentationDragIndicator(.visible) // ドラッグインジケーターを表示
        .interactiveDismissDisabled(shouldShowCloseConfirmation())

        // 下向きスワイプを検知して確認アラートを表示
        .simultaneousGesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.height > 0 {
                        if shouldShowCloseConfirmation() {
                            showingCloseConfirmation = true
                            hasPresentedAlert = false
                        }
                    }
                }
        )

        .task {
            // setContainerは同期的にisInitializedを立てるため、待機ループは不要
            viewModel.setContainer(diContainer, for: subject)
            efficientStopwatchManager.setSubject(subject)
            checkAndRestoreActiveSession()
            await viewModel.loadTodayRecords()
        }

        // ストップウォッチ動作中に閉じようとした場合の確認アラート
        .alert("ストップウォッチが動作中です", isPresented: $showingCloseConfirmation) {
            Button("リセットして閉じる", role: .destructive) {
                efficientStopwatchManager.reset()
                StudyActivityManager.shared.endActivity()
                dismissView()
            }

            Button("キャンセル", role: .cancel) {
                hasPresentedAlert = false
            }
        } message: {
            Text("ストップウォッチをリセットしてから閉じますか？")
        }

        .onChange(of: showingCloseConfirmation) { _, newValue in
            if newValue && !hasPresentedAlert {
                HapticFeedback.soft()
                hasPresentedAlert = true
            }
        }

        // 保存失敗時のエラーアラート
        .alert("保存できませんでした", isPresented: errorAlertBinding) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if !isPresented { viewModel.errorMessage = nil }
            }
        )
    }

    // MARK: - Actions

    private func handleCloseAction() {
        if shouldShowCloseConfirmation() {
            showingCloseConfirmation = true
            hasPresentedAlert = false
        } else {
            dismissView()
        }
    }

    private func shouldShowCloseConfirmation() -> Bool {
        efficientStopwatchManager.isRunning || efficientStopwatchManager.elapsedTime > 0
    }

    private func dismissView() {
        dismiss()
    }
    
    // セッション復元処理
    private func checkAndRestoreActiveSession() {
        if let activeSession = StudySessionManager.shared.getActiveSession(),
           activeSession.subjectId == subject.id {
            restoreFromActiveSession(activeSession)
            return
        }
        
        // フォールバック：LiveActivityStateまたは通常の状態復元（同じ教材の場合のみ）
        efficientStopwatchManager.restoreStateIfNeeded(for: subject.id)
    }
    
    // アクティブセッションからの復元処理
    private func restoreFromActiveSession(_ activeSession: StudySessionState) {
        if activeSession.isRunning {
            // アプリ終了中の経過時間を計算
            let timeSinceLastUpdate = Date().timeIntervalSince(activeSession.lastUpdateTime)
            
            let totalAccumulated = activeSession.accumulatedTime + timeSinceLastUpdate
            
            efficientStopwatchManager.setAccumulatedTime(totalAccumulated)
            efficientStopwatchManager.setElapsedTime(totalAccumulated)
            
            Task {
                // 全ライブアクティビティをクリアしてから再開
                await StudyActivityManager.shared.clearAllActivitiesOnAppLaunch()
                
                efficientStopwatchManager.startWithLiveActivity(for: subject)
            }
        } else {
            // 停止状態での復元
            efficientStopwatchManager.setAccumulatedTime(activeSession.accumulatedTime)
            efficientStopwatchManager.setElapsedTime(activeSession.elapsedTime)
            
            // 停止状態でも古いライブアクティビティをクリア
            Task {
                await StudyActivityManager.shared.clearAllActivitiesOnAppLaunch()
            }
        }
    }
    
    // MARK: - Views
    
    private var subjectHeader: some View {
        return VStack(spacing: 12) {
            HStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(subject.color)
                    .frame(width: 4.8, height: 70)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(subject.name)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("今日の学習時間")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(viewModel.todayTotalTimeText)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(subject.name)、今日の学習時間 \(viewModel.todayTotalTimeText)")

                Spacer()
            }

            Divider()
        }
    }
    
    private var timeInputSection: some View {
        return VStack(alignment: .leading, spacing: 12) {
            HStack{
                Text("学習時間を入力")
                    .font(.headline)
                if (viewModel.inputHours > 0 || viewModel.inputMinutes > 0) && efficientStopwatchManager.elapsedTime > 0 {
                    let inputSeconds = TimeInterval(viewModel.inputHours * 3600 + viewModel.inputMinutes * 60)
                    let totalSeconds = inputSeconds + efficientStopwatchManager.elapsedTime
                    let totalHours = Int(totalSeconds) / 3600
                    let totalMinutes = (Int(totalSeconds) % 3600) / 60

                    Text("合計: \(totalHours)時間\(totalMinutes)分")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 2)
                }
            }
            
            HStack {
                Spacer()
                TwoComponentTimePicker(hours: $viewModel.inputHours, minutes: $viewModel.inputMinutes)
                    .frame(height: 160)
                Spacer()
            }

                    }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(26)
    }
    
    private var efficientStopwatchSection: some View {
        return AdaptiveStopwatchView(
            stopwatchManager: efficientStopwatchManager,
            subject: subject
        )
    }
    
    private var saveButton: some View {
        return Button(action: {
            Task {
                await saveStudyRecordWithEfficientStopwatch()
                if !viewModel.isSaving && viewModel.errorMessage == nil {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    dismissView()
                }
            }
        }) {
            HStack {
                if viewModel.isSaving {
                    ProgressView()
                        .scaleEffect(0.8)
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                }

                Text(viewModel.isSaving ? "保存中..." : "学習記録を保存")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(canSave && !viewModel.isSaving ? Color.blue : Color.gray)
            .cornerRadius(26)
            .glassEffect()
        }
        .disabled(!canSave || viewModel.isSaving)
        .accessibilityLabel(viewModel.isSaving ? "保存中" : "学習記録を保存")
    }

    // MARK: - Helper Methods
    
    private var canSave: Bool {
        let inputTime = TimeInterval(viewModel.inputHours * 3600 + viewModel.inputMinutes * 60)
        let result = inputTime > 0 || efficientStopwatchManager.elapsedTime > 0
        return result
    }
    
    private func saveStudyRecordWithEfficientStopwatch() async {
        let success = await viewModel.saveStudyRecordWithStopwatch(
            inputHours: viewModel.inputHours,
            inputMinutes: viewModel.inputMinutes,
            stopwatchElapsed: efficientStopwatchManager.elapsedTime
        )
        
        if success {
            HapticFeedback.success()
            await StudyActivityManager.shared.endActivity()
            viewModel.inputHours = 0
            viewModel.inputMinutes = 0
            efficientStopwatchManager.reset()
            await viewModel.loadTodayRecords()
        } else {
            HapticFeedback.error()
        }
    }
}

#Preview {
    StudySessionView(
        subject: Subject(name: "数学", color: .blue, sortOrder: 0)
    )
    .environment(DIContainer.shared)
}
