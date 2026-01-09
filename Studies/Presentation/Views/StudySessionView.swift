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
        print("🏗️ StudySessionView init for subject: \(subject.name) (ID: \(subject.id))")
    }
    
    var body: some View {
        let _ = print("🎬 StudySessionView body called for subject: \(subject.name)")
        let _ = print("🎬 DIContainer exists: \(diContainer != nil)")
        let _ = print("🎬 ViewModel initialized: \(viewModel.isInitialized)")
        
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    let _ = print("🎬 Rendering subjectHeader")
                    subjectHeader
                    
                    let _ = print("🎬 Rendering timeInputSection")
                    timeInputSection
                    
                    let _ = print("🎬 Rendering efficientStopwatchSection")
                    efficientStopwatchSection
                    
                    let _ = print("🎬 Rendering saveButton")
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
                    print("🔴 Close button tapped")
                                            handleCloseAction()
                    })
                        .labelStyle(.iconOnly)
                }
            }
        }
        // 🔥 修正: 完全なスワイプ閉じ防止
        .presentationDetents([.large])
        .presentationDragIndicator(.visible) // ドラッグインジケーターを表示
        .interactiveDismissDisabled(shouldShowCloseConfirmation())
        
        // 🔥 修正: シンプルなスワイプ検知
        .simultaneousGesture(
            DragGesture()
                .onEnded { value in
                    // 下向きスワイプを検知（距離や速度に関係なく）
                    if value.translation.height > 0 {
                        print("📱 下向きスワイプ検知: \(value.translation.height)")
                        if shouldShowCloseConfirmation() {
                            showingCloseConfirmation = true
                            hasPresentedAlert = false
                        }
                    }
                }
        )
        
        .onAppear {
            print("👁️ StudySessionView onAppear called")
            print("👁️ Subject: \(subject.name) (ID: \(subject.id))")
            print("👁️ DIContainer: \(diContainer)")
            
            // DIContainerの確認と設定
            guard diContainer != nil else {
                print("❌ DIContainer is nil on StudySessionView appear")
                return
            }
            
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
                    print("✅ Today records loaded for \(subject.name)")
                } else {
                    print("❌ Failed to initialize ViewModel for \(subject.name)")
                }
            }
        }

        
        .task {
            print("📋 Task started - checking initialization...")
            var attemptCount = 0
            while !viewModel.isInitialized {
                attemptCount += 1
                print("📋 Initialization attempt \(attemptCount)")
                if attemptCount > 100 {
                    print("❌ Initialization timeout after 5 seconds")
                    break
                }
                
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
            
            if viewModel.isInitialized {
                print("✅ Container initialized, loading records...")
                await viewModel.loadTodayRecords()
                print("✅ Today records loaded")
            } else {
                print("❌ Failed to initialize container")
            }
        }
        
        .onDisappear {
            print("👋 StudySessionView onDisappear called")
            
            if efficientStopwatchManager.isRunning {
                print("⏹️ Stopping running stopwatch on disappear")
                efficientStopwatchManager.stop()
            }
            
            if efficientStopwatchManager.elapsedTime == 0 && !efficientStopwatchManager.isRunning {
                print("🔴 Ending Live Activity on disappear")
                StudyActivityManager.shared.endActivity()
            }
            
            print("👋 StudySessionView onDisappear completed")
        }
        
        // 通常のアラート
        .alert("ストップウォッチが動作中です", isPresented: $showingCloseConfirmation) {
            Button("リセットして閉じる", role: .destructive) {
                print("🔴 Resetting and closing from alert")
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
        print("🚪 handleCloseAction called")
        if shouldShowCloseConfirmation() {
            print("⚠️ Showing confirmation dialog")
            showingCloseConfirmation = true
            hasPresentedAlert = false
        } else {
            print("✅ Safe to dismiss")
            dismissView()
        }
    }
    
    // 🔥 修正: アラート表示判定を分離
    private func shouldShowCloseConfirmation() -> Bool {
        let shouldShow = efficientStopwatchManager.isRunning || efficientStopwatchManager.elapsedTime > 0
        print("🔍 shouldShowCloseConfirmation: \(shouldShow) (running: \(efficientStopwatchManager.isRunning), elapsed: \(efficientStopwatchManager.elapsedTime))")
        return shouldShow
    }
    
    private func dismissView() {
        print("🚪 Dismissing view")
        presentationMode.wrappedValue.dismiss()
    }
    
    // セッション復元処理
    private func checkAndRestoreActiveSession() {
        print("🔍 Checking for active session restoration...")
        // StudySessionManagerが利用可能かチェック
        do {
            let _ = StudySessionManager.self
            if let activeSession = StudySessionManager.shared.getActiveSession(),
               activeSession.subjectId == subject.id {
                print("🔄 Found matching active session for: \(subject.name)")
                restoreFromActiveSession(activeSession)
                return
            }
        } catch {
            print("⚠️ StudySessionManager not available: \(error)")
        }
        
        // フォールバック：LiveActivityStateまたは通常の状態復元
        print("📭 No matching StudySession found, trying LiveActivity state...")
        efficientStopwatchManager.restoreStateIfNeeded()
    }
    
    // アクティブセッションからの復元処理
    private func restoreFromActiveSession(_ activeSession: StudySessionState) {
        print("🔄 Restoring from active session: \(activeSession.subjectName)")
        print("🔄 Session details - elapsed: \(activeSession.elapsedTime), accumulated: \(activeSession.accumulatedTime), running: \(activeSession.isRunning)")
        
        if activeSession.isRunning {
            // アプリ終了中の経過時間を計算
            let timeSinceLastUpdate = Date().timeIntervalSince(activeSession.lastUpdateTime)
            print("⏰ Time since last update: \(timeSinceLastUpdate) seconds")
            
            let totalAccumulated = activeSession.accumulatedTime + timeSinceLastUpdate
            print("📊 Setting accumulated time to: \(totalAccumulated)")
            
            efficientStopwatchManager.setAccumulatedTime(totalAccumulated)
            efficientStopwatchManager.setElapsedTime(totalAccumulated)
            
            Task {
                print("🧹 Clearing all Live Activities before starting new one")
                // 全ライブアクティビティをクリアしてから再開
                await StudyActivityManager.shared.clearAllActivitiesOnAppLaunch()
                
                print("✅ All activities cleared, starting with Live Activity")
                efficientStopwatchManager.startWithLiveActivity(for: subject)
                print("▶️ Resumed stopwatch with accumulated time: \(totalAccumulated)")
            }
        } else {
            // 停止状態での復元
            print("⏸️ Restoring stopped state with elapsed time: \(activeSession.elapsedTime)")
            efficientStopwatchManager.setAccumulatedTime(activeSession.accumulatedTime)
            efficientStopwatchManager.setElapsedTime(activeSession.elapsedTime)
            
            // 停止状態でも古いライブアクティビティをクリア
            Task {
                await StudyActivityManager.shared.clearAllActivitiesOnAppLaunch()
            }
        }
        
        print("✅ Active session restoration completed")
    }
    
    // MARK: - Views
    
    private var subjectHeader: some View {
        let _ = print("📋 subjectHeader rendering - subject: \(subject.name) (ID: \(subject.id))")
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
        let _ = print("⏰ timeInputSection rendering")
        return VStack(alignment: .leading, spacing: 12) {
            Text("学習時間を入力")
                .font(.headline)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("時間")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("時間", selection: $viewModel.inputHours) {
                        ForEach(0..<24) { hour in
                            Text("\(hour)時間").tag(hour)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(height: 80)
                }
                .frame(maxWidth: .infinity)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("分")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("分", selection: $viewModel.inputMinutes) {
                        ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { minute in
                            Text("\(minute)分").tag(minute)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(height: 80)

                }
                .frame(maxWidth: .infinity)
            }
            
            if viewModel.inputHours > 0 || viewModel.inputMinutes > 0 {
                Text("選択中: \(viewModel.inputHours)時間\(viewModel.inputMinutes)分")
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(26)
    }
    
    private var efficientStopwatchSection: some View {
        let _ = print("⏱️ efficientStopwatchSection rendering")
        return AdaptiveStopwatchView(
            stopwatchManager: efficientStopwatchManager,
            subject: subject
        )
    }
    
    private var saveButton: some View {
        let _ = print("💾 saveButton rendering - canSave: \(canSave)")
        return Button(action: {
            print("💾 Save button tapped")
            Task {
                await saveStudyRecordWithEfficientStopwatch()
                if !viewModel.isSaving && viewModel.errorMessage == nil {
                    print("✅ Save successful, dismissing after delay")
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
        print("🔍 canSave check - inputTime: \(inputTime), stopwatchTime: \(efficientStopwatchManager.elapsedTime), result: \(result)")
        return result
    }
    
    private func saveStudyRecordWithEfficientStopwatch() async {
        print("💾 saveStudyRecordWithEfficientStopwatch called")
        print("💾 Input time: \(viewModel.inputHours)h \(viewModel.inputMinutes)m")
        print("💾 Stopwatch time: \(efficientStopwatchManager.elapsedTime) seconds")
        
        let success = await viewModel.saveStudyRecordWithStopwatch(
            inputHours: viewModel.inputHours,
            inputMinutes: viewModel.inputMinutes,
            stopwatchElapsed: efficientStopwatchManager.elapsedTime
        )
        
        if success {
            print("✅ Save successful")
            HapticFeedback.success()
            await StudyActivityManager.shared.endActivity()
            viewModel.inputHours = 0
            viewModel.inputMinutes = 0
            efficientStopwatchManager.reset()
            await viewModel.loadTodayRecords()
        } else {
            print("❌ Save failed")
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
