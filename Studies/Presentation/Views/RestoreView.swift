//
//  RestoreView.swift
//  Studies
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

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
        NavigationView {
            VStack {
                Spacer(minLength: 150)
                
                // ヘッダー説明
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
                
                // インポートと復元
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
                                    
                                    // ← 追加: アーカイブ状態の情報表示
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
        
        // セキュリティスコープリソースへのアクセスを開始
        guard url.startAccessingSecurityScopedResource() else {
            await MainActor.run {
                restoreStatus = .failed("ファイルへのアクセス権限を取得できませんでした")
            }
            print("セキュリティスコープアクセス失敗")
            return
        }
        
        // アクセス終了の処理を確実に実行
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
            
            let activeCount = backup.studyRecords.filter { !$0.isArchived }.count
            let archivedCount = backup.studyRecords.filter { $0.isArchived }.count
            print("バックアップファイルの読み込み完了: \(backup.subjects.count)教材, \(backup.studyRecords.count)記録 (アクティブ: \(activeCount), アーカイブ: \(archivedCount))")
            
        } catch {
            await MainActor.run {
                restoreStatus = .failed("ファイル解析エラー: \(error.localizedDescription)")
            }
            print("バックアップファイル読み込みエラー: \(error)")
        }
    }
    
    private func performRestore() async {
        guard let backup = backupData else { return }
        
        await MainActor.run { restoreStatus = .restoring }
        
        do {
            // 既存データを全削除
            try modelContext.delete(model: SubjectModel.self)
            try modelContext.delete(model: StudyRecordModel.self)
            
            // 教材データを復元
            for subjectBackup in backup.subjects {
                let subject = SubjectModel(
                    id: subjectBackup.id,
                    name: subjectBackup.name,
                    color: Color(
                        red: subjectBackup.colorRed,
                        green: subjectBackup.colorGreen,
                        blue: subjectBackup.colorBlue
                    ),
                    isPinned: subjectBackup.isPinned,
                    createdAt: subjectBackup.createdAt
                )
                modelContext.insert(subject)
            }
            
            // 学習記録データを復元（アーカイブ状態を含む）
            for recordBackup in backup.studyRecords {
                let record = StudyRecordModel(
                    id: recordBackup.id,
                    subjectId: recordBackup.subjectId,
                    studyDate: recordBackup.studyDate,
                    duration: recordBackup.duration,
                    createdAt: recordBackup.createdAt,
                    isArchived: recordBackup.isArchived  // ← 追加: アーカイブ状態を復元
                )
                modelContext.insert(record)
            }
            
            try modelContext.save()
            
            await MainActor.run {
                restoreStatus = .completed
            }
            
            let activeCount = backup.studyRecords.filter { !$0.isArchived }.count
            let archivedCount = backup.studyRecords.filter { $0.isArchived }.count
            print("データ復元完了: \(backup.subjects.count)教材, \(backup.studyRecords.count)記録 (アクティブ: \(activeCount), アーカイブ: \(archivedCount))")
            
        } catch {
            await MainActor.run {
                restoreStatus = .failed("復元エラー: \(error.localizedDescription)")
            }
            print("データ復元エラー: \(error)")
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
