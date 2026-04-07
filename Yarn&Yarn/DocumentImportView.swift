//
//  DocumentImportView.swift
//  Yarn&Yarn
//
//  Created by Yangyang Long on 3/16/26.
//

import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

struct DocumentImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showingDocumentPicker = false
    @State private var documentTitle = ""
    @State private var importedData: Data?
    @State private var importedFileType: String?
    @State private var showingTitlePrompt = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Text("Import Instructions")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Add knitting or crocheting patterns to get started")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                VStack(spacing: 16) {
                    // Import from Photos
                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images
                    ) {
                        ImportOptionCard(
                            icon: "photo.on.rectangle",
                            title: "Import Image",
                            description: "Choose a photo from your library"
                        )
                    }
                    .onChange(of: selectedPhotoItem) { oldValue, newValue in
                        Task {
                            if let data = try? await newValue?.loadTransferable(type: Data.self) {
                                importedData = data
                                importedFileType = "image"
                                showingTitlePrompt = true
                            }
                        }
                    }
                    
                    // Import PDF
                    Button {
                        showingDocumentPicker = true
                    } label: {
                        ImportOptionCard(
                            icon: "doc.fill",
                            title: "Import PDF",
                            description: "Choose a PDF document"
                        )
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $showingDocumentPicker,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    if url.startAccessingSecurityScopedResource() {
                        defer { url.stopAccessingSecurityScopedResource() }
                        if let data = try? Data(contentsOf: url) {
                            importedData = data
                            importedFileType = "pdf"
                            showingTitlePrompt = true
                        }
                    }
                case .failure(let error):
                    print("Error importing: \(error.localizedDescription)")
                }
            }
            .alert("Name Your Pattern", isPresented: $showingTitlePrompt) {
                TextField("Pattern name", text: $documentTitle)
                Button("Cancel", role: .cancel) {
                    importedData = nil
                    importedFileType = nil
                    documentTitle = ""
                }
                Button("Save") {
                    saveDocument()
                }
            } message: {
                Text("Give your knitting or crocheting pattern a name")
            }
        }
    }
    
    private func saveDocument() {
        guard let data = importedData,
              let fileType = importedFileType else { return }
        
        let title = documentTitle.isEmpty ? "Untitled Pattern" : documentTitle
        
        withAnimation {
            let newDocument = InstructionDocument(
                title: title,
                fileData: data,
                fileType: fileType
            )
            modelContext.insert(newDocument)
        }
        
        dismiss()
    }
}

struct ImportOptionCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(.blue)
                .frame(width: 60)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
}

#Preview {
    DocumentImportView()
        .modelContainer(for: InstructionDocument.self, inMemory: true)
}
