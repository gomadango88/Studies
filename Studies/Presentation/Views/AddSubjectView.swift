//
//  AddSubjectView.swift
//  Studies
//
//  Created by kasahara takuma on 2025/08/08.
//

import SwiftUI

struct AddSubjectView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DIContainer.self) private var diContainer
    @State private var viewModel: AddSubjectViewModel
    
    let onSubjectAdded: () -> Void
    
    private let presetColors: [Color] = [.blue, .green, .orange, .red, .purple]
    
    private var isCustomColorSelected: Bool {
        !presetColors.contains(viewModel.selectedColor)
    }
    
    private var canSave: Bool {
        !viewModel.subjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isSaving
    }
    
    private func attemptSave() {
        guard canSave else { return }
        Task {
            let success = await viewModel.saveSubject()
            if success {
                onSubjectAdded()
                dismiss()
            }
        }
    }
    
    init(onSubjectAdded: @escaping () -> Void) {
        self.onSubjectAdded = onSubjectAdded
        self._viewModel = State(wrappedValue: AddSubjectViewModel())
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("教材名")
                        Spacer()
                        TextField("例: 数学", text: $viewModel.subjectName)
                            .multilineTextAlignment(.trailing)
                            .submitLabel(.done)
                            .onSubmit { attemptSave() }
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                } footer: {
                    if viewModel.subjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("教材名を入力してください")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 16) {
                        ForEach(presetColors, id: \.self) { color in
                            Circle()
                                .fill(color)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle()
                                        .stroke(viewModel.selectedColor == color ? Color.primary : Color.clear, lineWidth: 2)
                                )
                                .onTapGesture { viewModel.selectedColor = color }
                        }

                        ColorPicker("", selection: $viewModel.selectedColor)
                            .labelsHidden()
                            .frame(width: 30, height: 30)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.primary, lineWidth: 2)
                                    .opacity(isCustomColorSelected ? 1 : 0)
                            )
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("色")
                }
                
                Section {
                    Toggle("ピン留めする", isOn: $viewModel.isPinned)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
                
                Section {
                    HStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(viewModel.selectedColor)
                            .frame(width: 4, height: 50)
                        
                        VStack(alignment: .leading) {
                            Text(viewModel.subjectName.isEmpty ? "教材名" : viewModel.subjectName)
                                .font(.headline)
                            
                            Text("プレビュー")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("プレビュー")
                }
                
                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("新しい教材")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル", systemImage: "xmark", action: {dismiss()})
                        .labelStyle(.iconOnly)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存", systemImage: "checkmark", action: { attemptSave() })
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.subjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSaving)
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                viewModel.setContainer(diContainer)
            }
            .interactiveDismissDisabled(viewModel.isSaving)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}

#Preview {
    AddSubjectView(onSubjectAdded: {})
        .environment(DIContainer.shared)
}
