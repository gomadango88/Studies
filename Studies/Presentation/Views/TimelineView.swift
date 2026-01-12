//
// TimelineView.swift
// Studies
//
// Created by takuma on 2025/08/08.
//

import SwiftUI
import WidgetKit

struct TimelineView: View {
    @Environment(DIContainer.self) private var diContainer
    @State private var viewModel: TimelineViewModel
    
    // 削除確認アラート用の状態管理
    @State private var recordToDelete: StudyRecord?
    @State private var showingDeleteAlert = false
    
    // パフォーマンス最適化用
    @State private var isContextMenuReady = false
    
    init() {
        self._viewModel = State(wrappedValue: TimelineViewModel())
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.groupedRecords.isEmpty {
                    emptyStateView
                } else {
                    optimizedTimelineScrollView
                }
            }
            .navigationTitle("学習履歴")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                viewModel.setContainer(diContainer)
                Task {
                    await viewModel.loadAllRecords()
                    // データ読み込み完了後にコンテキストメニューを準備
                    isContextMenuReady = true
                }
            }
            // 削除確認アラート
            .alert("記録を削除しますか？", isPresented: $showingDeleteAlert, presenting: recordToDelete) { record in
                Button("削除", role: .destructive) {
                    Task {
                        await viewModel.deleteRecord(record)
                        
                        // 🔥 変更: ウィジェット更新は集中サービス経由
                        await updateWidgetAfterDeletion()
                        
                        // 削除成功時の触覚フィードバック
                        HapticFeedback.success()
                    }
                }
                
                Button("キャンセル", role: .cancel) {
                    recordToDelete = nil
                }
                
            } message: { record in
                Text("この学習記録を削除します。\nこの操作は取り消せません。")
            }
        }
    }
    
    // MARK: - ウィジェット更新メソッド
    private func updateWidgetAfterDeletion() async {
        print("📱 Updating widget after timeline record deletion via WidgetUpdateService...")
        await WidgetUpdateService.update(using: diContainer)
    }

    
    // MARK: - Views
    
    private var loadingView: some View {
        VStack {
            ProgressView()
                .scaleEffect(1.2)
            Text("読み込み中...")
                .foregroundColor(.secondary)
                .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("学習記録がありません")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("学習を開始すると\nこちらに履歴が表示されます")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var optimizedTimelineScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.groupedRecords, id: \.date) { group in
                    Section {
                        LazyVStack(spacing: 8) {
                            ForEach(group.records) { record in
                                OptimizedTimelineRecordCard(
                                    record: record,
                                    subject: viewModel.subjects.first { $0.id == record.subjectId },
                                    isContextMenuReady: isContextMenuReady,
                                    onDelete: {
                                        recordToDelete = record
                                        showingDeleteAlert = true
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    } header: {
                        TimelineDateHeader(date: group.date)
                    }
                }
                
                // 底部のスペース
                Color.clear.frame(height: 20)
            }
        }
    }
}

// MARK: - Timeline Components

struct TimelineDateHeader: View {
    let date: Date
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(date.formatted(.dateTime.month().day()))
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(date.formatted(.dateTime.weekday(.wide)))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if date.isToday {
                Text("今日")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .cornerRadius(8)
            } else if Calendar.current.isDateInYesterday(date) {
                Text("昨日")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray)
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}

// MARK: - Optimized Timeline Record Card

struct OptimizedTimelineRecordCard: View {
    let record: StudyRecord
    let subject: Subject?
    let isContextMenuReady: Bool
    let onDelete: () -> Void
    
    // パフォーマンス最適化用のキャッシュ
    @State private var cachedDurationText: String = ""
    @State private var isLongPressing = false
    
    var body: some View {
        HStack(spacing: 12) {
            // タイムライン線とドット
            timelineDot
            
            // 記録カード
            recordCardContent
        }
        .padding(.leading, 12)
        .scaleEffect(isLongPressing ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isLongPressing)
        .onAppear {
            // 表示時に一度だけ時間フォーマットを計算してキャッシュ
            if cachedDurationText.isEmpty {
                cachedDurationText = formatDuration(record.duration)
            }
        }
        // 最適化されたコンテキストメニュー
        .contextMenu {
            if isContextMenuReady {
                contextMenuContent
            }
        } preview: {
            if isContextMenuReady {
                OptimizedTimelineRecordPreview(
                    record: record,
                    subject: subject,
                    cachedDurationText: cachedDurationText
                )
            }
        }
        // 長押し状態の視覚フィードバック
        .onLongPressGesture(
            minimumDuration: 0.3,
            maximumDistance: 10,
            perform: {},
            onPressingChanged: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isLongPressing = pressing
                }
            }
        )
    }
    
    
    private var timelineDot: some View {
        VStack {
            Circle()
                .fill(subject?.color ?? Color.gray)
                .frame(width: 8, height: 8)
            
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 2)
                .frame(maxHeight: .infinity)
        }
        .frame(height: 60)
    }
    
    private var recordCardContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // 教材情報
                HStack(spacing: 8) {
                    if let subject = subject {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(subject.color)
                            .frame(width: 4, height: 20)
                        
                        Text(subject.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                    } else {
                        Text("削除された教材")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // キャッシュされた学習時間
                Text(cachedDurationText)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            // 時刻表示
            HStack {
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(record.studyDate.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    @ViewBuilder
    private var contextMenuContent: some View {
        Button {
            onDelete()
        } label: {
            Label("削除", systemImage: "trash")
        }
        .foregroundColor(.red)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)時間\(minutes)分"
        } else if minutes > 0 {
            return "\(minutes)分"
        } else {
            return "1分未満"
        }
    }
}

// MARK: - Optimized Context Menu Preview

struct OptimizedTimelineRecordPreview: View {
    let record: StudyRecord
    let subject: Subject?
    let cachedDurationText: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 教材情報
            HStack {
                if let subject = subject {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(subject.color)
                        .frame(width: 4, height: 40)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(subject.name)
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Text("学習記録")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray)
                        .frame(width: 4, height: 40)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("削除された教材")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("学習記録")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            Divider()
            
            // 詳細情報（キャッシュされたテキストを使用）
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.blue)
                    
                    Text("学習時間")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(cachedDurationText)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.green)
                    
                    Text("記録日時")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(record.studyDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .frame(width: 250)
    }
}

#Preview {
    TimelineView()
        .environment(DIContainer.shared)
}
