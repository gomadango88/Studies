//
//  RestoreView.swift
//  Studies
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import os

struct RestoreView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var isImporting = false
    @State private var restoreStatus: RestoreStatus = .idle
    @State private var backupData: BackupData?
    @State private var showingRestoreConfirmation = false
    
    enum RestoreStatus {
        case idle, importing, analyzing, ready, restoring, completed, failed(String)
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                Spacer(minLength: 150)

                VStack(spacing: 8) {
                    Image(systemName: "externaldrive.badge.timemachine")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    
                    Text("データ復元")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("バックアップファイルからデータを復元します。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()

                VStack(spacing: 16) {
                    switch restoreStatus {
                    case .idle:
                        Button {
                            isImporting = true
                        } label: {
                            Label("バックアップファイルを選択", systemImage: "doc.badge.plus")
                        }
                        .buttonStyle(.borderedProminent)
                        
                    case .importing:
                        ProgressView("ファイルを読み込み中...")
                        
                    case .analyzing:
                        ProgressView("データを解析中...")
                        
                    case .ready:
                        if let data = backupData {
                            VStack(spacing: 16) {
                                VStack(spacing: 8) {
                                    Text("復元準備完了")
                                        .font(.headline)
                                        .foregroundColor(.blue)
                                    
                                    Text("バックアップ日時: \(formatDate(data.exportDate))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    HStack {
                                        Label("\(data.subjects.count)個の教材", systemImage: "book")
                                        Spacer()
                                        Label("\(data.studyRecords.count)件の記録", systemImage: "clock")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                    // 達成記録・スケジュールの情報表示（旧フォーマットでは含まれない）
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
                                
                                VStack(spacing: 8) {
                                    Text("⚠️ 注意")
                                        .font(.headline)
                                        .foregroundColor(.orange)
                                    Text("現在のデータは全て削除され、バックアップデータ（アーカイブ状態を含む）で置き換えられます。この操作は取り消せません。")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .padding()
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(8)
                                
                                Button {
                                    showingRestoreConfirmation = true
                                } label: {
                                    Label("データを復元", systemImage: "arrow.clockwise")
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                            }
                        }
                        
                    case .restoring:
                        ProgressView("データを復元中...")
                        
                    case .completed:
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.green)
                            Text("復元完了")
                                .font(.headline)
                                .foregroundColor(.green)
                            Text("アーカイブ状態を含むすべてのデータが正常に復元されました")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                    case .failed(let error):
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.red)
                            Text("復元失敗")
                                .font(.headline)
                                .foregroundColor(.red)
                            Text(error)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button("再試行") {
                                restoreStatus = .idle
                                backupData = nil
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                
                Spacer()
            }
            .padding()
            .navigationTitle("復元")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了", systemImage: "xmark", action: {dismiss()})
                        .labelStyle(.iconOnly)
                }
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            Task {
                await handleFileImport(result)
            }
        }
        .alert("データ復元の確認", isPresented: $showingRestoreConfirmation) {
            Button("復元する", role: .destructive) {
                Task {
                    await performRestore()
                }
            }
            Button("キャンセル", role: .cancel) { }
        } message: {
            Text("現在のすべてのデータが削除され、バックアップデータで置き換えられます。この操作は取り消せません。")
        }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) async {
        await MainActor.run { restoreStatus = .importing }
        
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                await MainActor.run {
                    restoreStatus = .failed("ファイルが選択されていません")
                }
                return
            }
            
            await loadBackupFile(from: url)
            
        case .failure(let error):
            await MainActor.run {
                restoreStatus = .failed("ファイル選択エラー: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadBackupFile(from url: URL) async {
        await MainActor.run { restoreStatus = .analyzing }
        
        guard url.startAccessingSecurityScopedResource() else {
            await MainActor.run {
                restoreStatus = .failed("ファイルへのアクセス権限を取得できませんでした")
            }
            Logger.data.error("セキュリティスコープアクセス失敗")
            return
        }

        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let backup = try decoder.decode(BackupData.self, from: data)
            
            await MainActor.run {
                self.backupData = backup
                self.restoreStatus = .ready
            }
            
        } catch {
            await MainActor.run {
                restoreStatus = .failed("ファイル解析エラー: \(error.localizedDescription)")
            }
            Logger.data.error("バックアップファイル読み込みエラー: \(error)")
        }
    }
    
    private func performRestore() async {
        guard let backup = backupData else { return }
        
        await MainActor.run { restoreStatus = .restoring }
        
        do {
            // 旧フォーマットの復元でも全タイプを削除し、古い達成記録・スケジュールが残らないようにする
            try modelContext.delete(model: SubjectModel.self)
            try modelContext.delete(model: StudyRecordModel.self)
            try modelContext.delete(model: DailyAchievementModel.self)
            try modelContext.delete(model: StudyScheduleModel.self)
            try modelContext.delete(model: SubjectGoalModel.self)  // 孤児レコードも含めて確実に削除

            for subjectBackup in backup.subjects {
                let subject = SubjectModel(
                    id: subjectBackup.id,
                    name: subjectBackup.name,
                    color: Color(
                        red: subjectBackup.colorRed,
                        green: subjectBackup.colorGreen,
                        blue: subjectBackup.colorBlue,
                        opacity: subjectBackup.colorAlpha
                    ),
                    sortOrder: subjectBackup.sortOrder,
                    isPinned: subjectBackup.isPinned,
                    createdAt: subjectBackup.createdAt
                )
                modelContext.insert(subject)
            }

            for recordBackup in backup.studyRecords {
                let record = StudyRecordModel(
                    id: recordBackup.id,
                    subjectId: recordBackup.subjectId,
                    studyDate: recordBackup.studyDate,
                    duration: recordBackup.duration,
                    createdAt: recordBackup.createdAt,
                    isArchived: recordBackup.isArchived
                )
                modelContext.insert(record)
            }

            // 達成記録を復元（v2.0以降のバックアップのみ。旧フォーマットでは空になる）
            for achievementBackup in backup.dailyAchievements ?? [] {
                let achievement = DailyAchievementModel(
                    date: achievementBackup.date,
                    subjectId: achievementBackup.subjectId,
                    requiredMinutes: achievementBackup.requiredMinutes,
                    achievedMinutes: achievementBackup.achievedMinutes,
                    achieved: achievementBackup.achieved,
                    computedAt: achievementBackup.computedAt
                )
                modelContext.insert(achievement)
            }

            // スケジュールを復元（v2.0以降のバックアップのみ。SubjectGoalも入れ子で復元）
            for scheduleBackup in backup.schedules ?? [] {
                let schedule = StudyScheduleModel(
                    id: scheduleBackup.id,
                    name: scheduleBackup.name,
                    dailyGoalMinutes: scheduleBackup.dailyGoalMinutes,
                    selectedWeekdaysMask: scheduleBackup.selectedWeekdaysMask,
                    isEnabled: scheduleBackup.isEnabled,
                    colorRed: scheduleBackup.colorRed,
                    colorGreen: scheduleBackup.colorGreen,
                    colorBlue: scheduleBackup.colorBlue,
                    colorAlpha: scheduleBackup.colorAlpha,
                    priority: scheduleBackup.priority
                )
                modelContext.insert(schedule)

                schedule.subjectGoals = scheduleBackup.subjectGoals.map { goalBackup in
                    let goal = SubjectGoalModel(
                        id: goalBackup.id,
                        subjectId: goalBackup.subjectId,
                        subjectName: goalBackup.subjectName,
                        subjectColorRed: goalBackup.subjectColorRed,
                        subjectColorGreen: goalBackup.subjectColorGreen,
                        subjectColorBlue: goalBackup.subjectColorBlue,
                        subjectColorAlpha: goalBackup.subjectColorAlpha,
                        goalMinutes: goalBackup.goalMinutes,
                        isEnabled: goalBackup.isEnabled
                    )
                    goal.schedule = schedule
                    return goal
                }
            }

            try modelContext.save()
            
            await MainActor.run {
                restoreStatus = .completed
            }
            
        } catch {
            await MainActor.run {
                restoreStatus = .failed("復元エラー: \(error.localizedDescription)")
            }
            Logger.data.error("データ復元エラー: \(error)")
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}

#Preview {
    RestoreView()
        .modelContainer(for: [StudyRecordModel.self, SubjectModel.self])
}
