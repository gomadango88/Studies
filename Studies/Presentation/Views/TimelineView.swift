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
    
    init() {
        self._viewModel = State(wrappedValue: TimelineViewModel())
    }
    
    var body: some View {
        NavigationStack {
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
            .background(backdrop)
        }
    }
    
    // MARK: - ウィジェット更新メソッド
    private func updateWidgetAfterDeletion() async {
        print("📱 Updating widget after timeline record deletion via WidgetUpdateService...")
        await WidgetUpdateService.update(using: diContainer)
    }
    
    
    private var backdrop: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.systemGroupedBackground), Color(.systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            LinearGradient(
                colors: [Color.blue.opacity(0.12), Color.purple.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blur(radius: 80)
        }
        .ignoresSafeArea()
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
            Image(systemName: "books.vertical")
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
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
        List {
            ForEach(viewModel.groupedRecords, id: \.date) { group in
                Group {
                    TimelineDateHeader(date: group.date)
                        .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .background(Color.clear)

                    ForEach(group.records) { record in
                        OptimizedTimelineRecordCard(
                            record: record,
                            subject: viewModel.subjects.first { $0.id == record.subjectId },
                            onDelete: {
                                recordToDelete = record
                                showingDeleteAlert = true
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .background(Color.clear)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Timeline Components

struct TimelineDateHeader: View {
    let date: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(date.formatted(.dateTime.month().day()))
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                if date.isToday {
                    Text("今日")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.blue)
                } else if Calendar.current.isDateInYesterday(date) {
                    Text("昨日")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.gray)
                }

                Spacer()
            }

            Text(date.formatted(.dateTime.weekday(.wide)))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
}

// MARK: - Optimized Timeline Record Card

struct OptimizedTimelineRecordCard: View {
    let record: StudyRecord
    let subject: Subject?
    let onDelete: () -> Void
    
    // パフォーマンス最適化用のキャッシュ
    @State private var cachedDurationText: String = ""
    
    var body: some View {
        HStack(spacing: 12) {
            // タイムライン線とドット
            timelineDot
            
            // 記録カード
            recordCardContent
        }
        .padding(.leading, 12)
        .onAppear {
            // 表示時に一度だけ時間フォーマットを計算してキャッシュ
            if cachedDurationText.isEmpty {
                cachedDurationText = formatDuration(record.duration)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
    }
    
    
    private var timelineDot: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(subject?.color ?? Color.gray)
                .frame(width: 8, height: 8)

            Rectangle()
                .fill(Color.gray.opacity(0.25))
                .frame(width: 1)
                .frame(maxHeight: .infinity)
        }
        .frame(height: 56)
    }
    
    private var recordCardContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                if let subject = subject {
                    Text(subject.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                } else {
                    Text("削除された教材")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(cachedDurationText)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text(record.studyDate.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }
        }
        .padding(.trailing, 12)
        .overlay(
            Divider().opacity(0.25),
            alignment: .bottom
        )
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
#Preview {
    TimelineView()
        .environment(DIContainer.shared)
}

