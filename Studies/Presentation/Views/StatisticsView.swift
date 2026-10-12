//
//  StatisticsView.swift
//  Studies
//
//  統計画面
//

import SwiftUI

struct StatisticsView: View {
    @Environment(DIContainer.self) private var di
    @State private var showStudyRecordList = false
    @State private var showBackupView = false
    @State private var showRestoreView = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                StudyTimeCharts()
                Spacer()
            }
            .navigationTitle("統計")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showStudyRecordList = true
                        } label: {
                            Label("学習記録一覧", systemImage: "list.bullet")
                        }

                        Divider()

                        Button {
                            showBackupView = true
                        } label: {
                            Label("バックアップ", systemImage: "externaldrive.badge.plus")
                        }

                        Button {
                            showRestoreView = true
                        } label: {
                            Label("復元", systemImage: "externaldrive.badge.timemachine")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.title3)
                    }
                    .accessibilityLabel("その他のオプション")
                }
            }
            .background(GradientBackdrop())
        }
        .ignoresSafeArea(.container, edges: .top)
        .sheet(isPresented: $showStudyRecordList) {
            StudyRecordListView()
        }
        .sheet(isPresented: $showBackupView) {
            BackupView()
        }
        .sheet(isPresented: $showRestoreView) {
            RestoreView()
        }
    }
}

// MARK: - Preview
#Preview {
    StatisticsView()
        .environment(DIContainer.shared)
}
