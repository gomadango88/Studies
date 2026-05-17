//
// StudySessionView.swift
// Studies
//
// Created by takuma on 2025/08/08.
//

import SwiftUI

struct StudySessionView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(DIContainer.self) private var diContainer
    @State private var viewModel: StudySessionViewModel
    
    // アラート表示用の状態管理
    @State private var showingCloseConfirmation = false
    @State private var showingForceCloseAlert = false // 強制終了検出用
    @State private var hasPresentedAlert = false
    
    // 新しい効率的ストップウォッチマネージャー
    @State private var efficientStopwatchManager = EfficientStopwatchManager()
    
    let subject: Subject
    
    init(subject: Subject) {
        self.subject = subject
        self._viewModel = State(wrappedValue: StudySessionViewModel(subject: subject))
    }
    
    var body: some View {
        
        NavigationView {
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
                }
            }
        }
        // スワイプでの閉じる動作を制御
        .presentationDetents([.large])
        .presentationDragIndicator(.visible) // ドラッグインジケーターを表示
        .interactiveDismissDisabled(shouldShowCloseConfirmation())
        
        .onAppear {
            viewModel.setContainer(diContainer, for: subject)
            efficientStopwatchManager.setSubject(subject)
            
            Task {
                checkAndRestoreActiveSession()
                
                // 初期化完了まで待機
                var attempts = 0
                while !viewModel.isInitialized && attempts < 50 {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    attempts += 1
                }
                
                if viewModel.isInitialized {
                    await viewModel.loadTodayRecords()
                } else {
                    print("Failed to initialize ViewModel for \(subject.name)")
                }
            }
        }

        
        .task {
            var attemptCount = 0
            while !viewModel.isInitialized {
                attemptCount += 1
                if attemptCount > 100 {
                    break
                }
                
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
            
            if viewModel.isInitialized {
                await viewModel.loadTodayRecords()
            }
        }
        
        .onDisappear {
            if efficientStopwatchManager.isRunning {
                efficientStopwatchManager.stop()
            }
            
            if efficientStopwatchManager.elapsedTime == 0 && !efficientStopwatchManager.isRunning {
                StudyActivityManager.shared.endActivity()
            }
        }
        
        // 通常のアラート
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
        
        // 強制終了検出時のアラート
        .alert("ストップウォッチが動作中でした", isPresented: $showingForceCloseAlert) {
            Button("記録を保存", role: .none) {
                Task {
                    await saveStudyRecordWithEfficientStopwatch()
                    dismissView()
                }
            }
            
            Button("破棄して閉じる", role: .destructive) {
                efficientStopwatchManager.reset()
                StudyActivityManager.shared.endActivity()
                dismissView()
            }
        } message: {
            Text("ストップウォッチが動作中でしたが、画面が閉じられました。記録を保存しますか？")
        }
        
        .onChange(of: showingCloseConfirmation) { _, newValue in
            if newValue && !hasPresentedAlert {
                HapticFeedback.soft()
                hasPresentedAlert = true
            }
        }
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
        let shouldShow = efficientStopwatchManager.isRunning || efficientStopwatchManager.elapsedTime > 0
        return shouldShow
    }
    
    private func dismissView() {
        presentationMode.wrappedValue.dismiss()
    }
    
    // セッション復元処理
    private func checkAndRestoreActiveSession() {
        if let activeSession = StudySessionManager.shared.getActiveSession(),
           activeSession.subjectId == subject.id {
            restoreFromActiveSession(activeSession)
            return
        }
        
        // フォールバック：LiveActivityStateまたは通常の状態復元
        efficientStopwatchManager.restoreStateIfNeeded()
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
            print("Save failed")
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
