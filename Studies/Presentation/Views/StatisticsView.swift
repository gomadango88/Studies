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
        NavigationView {
            VStack(spacing: 20) {
                StudyTimeCharts()
                Spacer()
            }
            .navigationTitle("統計")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                // データ管理メニュー（バックアップ・復元を1つにまとめる）
                ToolbarItem{
                    Menu {
                        Button {
                            showBackupView = true
                        } label: {
                            Label("バックアップ", systemImage: "externaldrive.badge.plus")
                        }
                        
                        Button {
                            showRestoreView = true
                        } label: {
                            Label("データを復元", systemImage: "externaldrive.badge.timemachine")
                        }
                    } label: {
                        Image(systemName: "arrow.trianglehead.counterclockwise.rotate.90")
                            .font(.title3)
                            
                    }
                    .accessibilityLabel("データ管理メニュー")
                    
                }
                
                
                ToolbarSpacer()
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showStudyRecordList = true
                    } label: {
                        Image(systemName: "list.bullet")
                            .font(.title3)
                    }
                    .accessibilityLabel("学習記録一覧")
                }
            }
        }
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
