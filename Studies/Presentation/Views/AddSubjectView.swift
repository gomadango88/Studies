//
//  AddSubjectView.swift
//  Studies
//
//  Created by kasahara takuma on 2025/08/08.
//


//
//  AddSubjectView.swift
//  Studies
//
//  Created by takuma on 2025/08/08.
//

import SwiftUI

struct AddSubjectView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DIContainer.self) private var diContainer
    @State private var viewModel: AddSubjectViewModel
    
    let onSubjectAdded: () -> Void
    
    init(onSubjectAdded: @escaping () -> Void) {
        self.onSubjectAdded = onSubjectAdded
        self._viewModel = State(wrappedValue: AddSubjectViewModel())
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("教材名を入力", text: $viewModel.subjectName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                } header: {
                    Text("教材名")
                }
                
                Section {
                    ColorPicker("教材の色を選択", selection: $viewModel.selectedColor)
                        .padding(.vertical, 8)
                } header: {
                    Text("色")
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
            .navigationTitle("新しい教材")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル", systemImage: "xmark", action: {dismiss()})
                        .labelStyle(.iconOnly)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存", systemImage: "checkmark", action:{
                                            Task {
                                                let success = await viewModel.saveSubject()
                                                if success {
                                                    onSubjectAdded()
                                                    dismiss()
                                                }
                                            }
                                        } )
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderedProminent)
                    .disabled(viewModel.subjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSaving)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                viewModel.setContainer(diContainer)
            }
        }
    }
}

#Preview {
    AddSubjectView(onSubjectAdded: {})
        .environment(DIContainer.shared)
}
