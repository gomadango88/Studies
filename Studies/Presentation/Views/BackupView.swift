//
//  BackupView.swift
//  Studies
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import os

struct BackupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var isExporting = false
    @State private var backupStatus: BackupStatus = .idle
    @State private var backupData: BackupData?
    
    enum BackupStatus {
        case idle, preparing, ready, exporting, completed, failed(String)
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                Spacer(minLength: 150)

                VStack(spacing: 8) {
                    Image(systemName: "externaldrive.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text("データバックアップ")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("教材・学習記録・達成記録・スケジュールをJSONファイルとしてエクスポートします。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()

                VStack(spacing: 16) {
                    switch backupStatus {
                    case .idle:
                        Button {
                            Task {
                                await prepareBackupData()
                            }
                        } label: {
                            Label("バックアップデータを準備", systemImage: "doc.text")
                        }
                        .buttonStyle(.borderedProminent)
                        
                    case .preparing:
                        ProgressView("データを準備中...")
                        
                    case .ready:
                        VStack(spacing: 12) {
                            if let data = backupData {
                                VStack(spacing: 8) {
                                    Text("準備完了")
                                        .font(.headline)
                                        .foregroundColor(.green)
                                    
                                    HStack {
                                        Label("\(data.subjects.count)個の教材", systemImage: "book")
                                        Spacer()
                                        Label("\(data.studyRecords.count)件の記録", systemImage: "clock")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                    HStack {
                                        Label("\(data.dailyAchievements?.count ?? 0)件の達成記録", systemImage: "checkmark.seal")
                                        Spacer()
                                        Label("\(data.schedules?.count ?? 0)件のスケジュール", systemImage: "calendar")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                    HStack {
                                        let activeCount = data.studyRecords.filter { !$0.isArchived }.count
                                        let archivedCount = data.studyRecords.filter { $0.isArchived }.count

                                        Label("\(activeCount)件アクティブ", systemImage: "circle")
                                        Spacer()
                                        Label("\(archivedCount)件アーカイブ", systemImage: "archivebox")
                                    }
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                }
                            }
                            
                            Button {
                                isExporting = true
                            } label: {
                                Label("ファイルをエクスポート", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        
                    case .exporting:
                        ProgressView("エクスポート中...")
                        
                    case .completed:
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.green)
                            Text("バックアップ完了")
                                .font(.headline)
                                .foregroundColor(.green)
                            Text("アーカイブ状態を含むすべてのデータが保存されました")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                    case .failed(let error):
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.red)
                            Text("バックアップ失敗")
                                .font(.headline)
                                .foregroundColor(.red)
                            Text(error)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button("再試行") {
                                backupStatus = .idle
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                
                Spacer()
            }
            .padding()
            .navigationTitle("バックアップ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了", systemImage: "xmark", action: {dismiss()})
                        .labelStyle(.iconOnly)
                }
            }
        }
        .fileExporter(
            isPresented: $isExporting,
            document: backupData.map { BackupDocument(backupData: $0) },
            contentType: .json,
            defaultFilename: generateFilename()
        ) { result in
            backupStatus = .exporting
            switch result {
            case .success:
                backupStatus = .completed
            case .failure(let error):
                backupStatus = .failed(String(localized: "エクスポートエラー: \(error.localizedDescription)"))
                Logger.ui.error("バックアップエラー: \(error)")
            }
        }
    }
    
    private func prepareBackupData() async {
        backupStatus = .preparing
        
        do {
            let subjectDescriptor = FetchDescriptor<SubjectModel>()
            let recordDescriptor = FetchDescriptor<StudyRecordModel>()
            let achievementDescriptor = FetchDescriptor<DailyAchievementModel>()
            let scheduleDescriptor = FetchDescriptor<StudyScheduleModel>()

            let subjects = try modelContext.fetch(subjectDescriptor)
            let studyRecords = try modelContext.fetch(recordDescriptor)
            let achievements = try modelContext.fetch(achievementDescriptor)
            let schedules = try modelContext.fetch(scheduleDescriptor)

            let subjectBackups = subjects.map { SubjectBackup(from: $0) }
            let recordBackups = studyRecords.map { StudyRecordBackup(from: $0) }  // ← アーカイブ状態も含まれる
            let achievementBackups = achievements.map { DailyAchievementBackup(from: $0) }
            let scheduleBackups = schedules.map { StudyScheduleBackup(from: $0) }  // SubjectGoalも入れ子で含まれる

            let backup = BackupData(
                subjects: subjectBackups,
                studyRecords: recordBackups,
                dailyAchievements: achievementBackups,
                schedules: scheduleBackups
            )
            
            await MainActor.run {
                self.backupData = backup
                self.backupStatus = .ready
            }
            
        } catch {
            await MainActor.run {
                self.backupStatus = .failed(String(localized: "データ取得エラー: \(error.localizedDescription)"))
            }
            Logger.ui.error("バックアップデータ準備エラー: \(error)")
        }
    }
    
    private func generateFilename() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmm"
        return "StudyBackup_\(dateFormatter.string(from: Date())).json"
    }
}

#Preview {
    BackupView()
        .modelContainer(for: [StudyRecordModel.self, SubjectModel.self])
}

