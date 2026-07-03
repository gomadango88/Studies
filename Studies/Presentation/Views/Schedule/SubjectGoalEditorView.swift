//
// SubjectGoalEditorView.swift
// Studies
//
// Created by kasahara takuma on 2025/08/13.
//

import SwiftUI

struct SubjectGoalRow: View {
    let subjectGoal: SubjectGoal

    var body: some View {
        HStack {
            Circle()
                .fill(subjectGoal.uiColor)
                .frame(width: 12, height: 12)
            Text(subjectGoal.subjectName)
                .font(.body)
            Spacer()
            Text("\(subjectGoal.goalMinutes)分")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

struct SubjectGoalEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let availableSubjects: [Subject]
    let initialSubjectGoal: SubjectGoal?
    let onSave: (SubjectGoal) -> Void

    @State private var selectedSubject: Subject?
    @State private var selectedHours = 0
    @State private var selectedMinutes = 0

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("時間設定")) {
                    HStack {
                        Spacer()
                        TwoComponentTimePicker(hours: $selectedHours, minutes: $selectedMinutes)
                            .frame(height: 144)
                        Spacer()
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowBackground(Color.clear)
                }

                Section(header: Text("教材選択")) {
                    ForEach(availableSubjects) { subject in
                        HStack {
                            Circle()
                                .fill(subject.color)
                                .frame(width: 12, height: 12)
                            Text(subject.name)
                            Spacer()
                            if selectedSubject?.id == subject.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedSubject = subject
                        }
                    }
                }
            }
            .onAppear {
                if let initial = initialSubjectGoal {
                    selectedHours = max(0, min(23, initial.goalMinutes / 60))
                    let mins = max(0, min(59, initial.goalMinutes % 60))
                    selectedMinutes = (mins / 5) * 5
                    if let found = availableSubjects.first(where: { $0.id == initial.subjectId }) {
                        selectedSubject = found
                    }
                }
            }
            .navigationTitle(initialSubjectGoal == nil ? "教材別目標を追加" : "教材別目標を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル", systemImage: "xmark", action: {dismiss()})
                        .labelStyle(.iconOnly)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(initialSubjectGoal == nil ? "追加" : "保存", systemImage: "checkmark", action: {
                        if let subject = selectedSubject {
                            let subjectGoal = SubjectGoal(
                                id: initialSubjectGoal?.id ?? UUID(),
                                subjectId: subject.id,
                                subjectName: subject.name,
                                subjectColor: CodableColor(subject.color),
                                goalMinutes: selectedHours * 60 + selectedMinutes,
                                isEnabled: initialSubjectGoal?.isEnabled ?? true
                            )

                            onSave(subjectGoal)
                            dismiss()
                        }
                    })
                    .labelStyle(.iconOnly)
                    .fontWeight(.semibold)
                    .disabled(selectedSubject == nil || (selectedHours == 0 && selectedMinutes == 0))
                }
            }
        }
    }
}
