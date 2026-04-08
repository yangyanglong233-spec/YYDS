//
//  DocumentImportView.swift
//  Yarn&Yarn
//
//  Created by Yangyang Long on 3/16/26.
//

import SwiftUI
import SwiftData
import PhotosUI
import PDFKit
import UniformTypeIdentifiers

// MARK: - Tag presets (shared between import and edit)

let subjectTagPresets = ["hat", "top", "dress", "bag", "scarf", "socks", "blanket"]
let projectTagPresets = ["crochet", "knitting", "other"]

// MARK: - Imported file model (drives navigationDestination)

struct ImportedFile: Hashable {
    let data: Data
    let fileType: String        // "pdf" | "image"
    let suggestedTitle: String
}

// MARK: - Main import picker screen

struct DocumentImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showingDocumentPicker = false
    @State private var importedFile: ImportedFile?

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
                    .onChange(of: selectedPhotoItem) { _, newValue in
                        Task {
                            guard let data = try? await newValue?.loadTransferable(type: Data.self) else { return }
                            importedFile = ImportedFile(data: data, fileType: "image", suggestedTitle: "")
                        }
                    }

                    Button { showingDocumentPicker = true } label: {
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
                    Button("Cancel") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showingDocumentPicker,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                guard case .success(let urls) = result, let url = urls.first else { return }
                if url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }
                    if let data = try? Data(contentsOf: url) {
                        let name = url.deletingPathExtension().lastPathComponent
                        importedFile = ImportedFile(data: data, fileType: "pdf", suggestedTitle: name)
                    }
                }
            }
            .navigationDestination(item: $importedFile) { file in
                DocumentImportFormView(importedFile: file)
            }
        }
    }
}

// MARK: - Import form (step 2)

struct DocumentImportFormView: View {
    let importedFile: ImportedFile

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var selectedSubjectTags: Set<String> = []
    @State private var selectedProjectTags: Set<String> = []
    @State private var coverPhotoItem: PhotosPickerItem?
    @State private var customCoverData: Data?
    @State private var generatedCoverImage: UIImage?

    @AppStorage("customSubjectTags") private var customSubjectTagsRaw = ""
    @AppStorage("customProjectTags") private var customProjectTagsRaw = ""

    @State private var showingAddSubjectTag = false
    @State private var showingAddProjectTag = false
    @State private var newTagName = ""

    init(importedFile: ImportedFile) {
        self.importedFile = importedFile
        _title = State(initialValue: importedFile.suggestedTitle)
    }

    var allSubjectTags: [String] {
        subjectTagPresets + customSubjectTagsRaw
            .split(separator: ",").map(String.init).filter { !$0.isEmpty }
    }

    var allProjectTags: [String] {
        projectTagPresets + customProjectTagsRaw
            .split(separator: ",").map(String.init).filter { !$0.isEmpty }
    }

    var coverImage: UIImage? {
        if let data = customCoverData { return UIImage(data: data) }
        return generatedCoverImage
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    coverPreview
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    PhotosPicker(selection: $coverPhotoItem, matching: .images) {
                        Label("Change Cover Image", systemImage: "photo.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderless)
                    .onChange(of: coverPhotoItem) { _, item in
                        Task {
                            customCoverData = try? await item?.loadTransferable(type: Data.self)
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
            }

            Section("Pattern Name") {
                TextField("Pattern name", text: $title)
            }

            Section {
                TagPickerRow(
                    tags: allSubjectTags,
                    selected: $selectedSubjectTags,
                    onAddTap: { showingAddSubjectTag = true }
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            } header: {
                Text("Subject (Optional)")
            }

            Section {
                TagPickerRow(
                    tags: allProjectTags,
                    selected: $selectedProjectTags,
                    onAddTap: { showingAddProjectTag = true }
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            } header: {
                Text("Project Type (Optional)")
            }
        }
        .navigationTitle("New Pattern")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { saveDocument() }
                    .fontWeight(.semibold)
            }
        }
        .task { await generateCover() }
        .alert("New Subject Tag", isPresented: $showingAddSubjectTag) {
            TextField("Tag name", text: $newTagName)
            Button("Cancel", role: .cancel) { newTagName = "" }
            Button("Add") { addCustomTag(to: &customSubjectTagsRaw, selecting: &selectedSubjectTags) }
        }
        .alert("New Project Tag", isPresented: $showingAddProjectTag) {
            TextField("Tag name", text: $newTagName)
            Button("Cancel", role: .cancel) { newTagName = "" }
            Button("Add") { addCustomTag(to: &customProjectTagsRaw, selecting: &selectedProjectTags) }
        }
    }

    @ViewBuilder
    private var coverPreview: some View {
        if let img = coverImage {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemBackground))
                .overlay { ProgressView() }
        }
    }

    private func generateCover() async {
        guard customCoverData == nil else { return }
        if importedFile.fileType == "pdf",
           let pdf = PDFDocument(data: importedFile.data),
           let page = pdf.page(at: 0) {
            generatedCoverImage = page.thumbnail(
                of: CGSize(width: 400, height: 560), for: .mediaBox
            )
        } else if importedFile.fileType == "image" {
            generatedCoverImage = UIImage(data: importedFile.data)
        }
    }

    private func addCustomTag(to storage: inout String, selecting selected: inout Set<String>) {
        let tag = newTagName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !tag.isEmpty else { newTagName = ""; return }
        if !storage.split(separator: ",").map(String.init).contains(tag) {
            storage = storage.isEmpty ? tag : storage + "," + tag
        }
        selected.insert(tag)
        newTagName = ""
    }

    private func saveDocument() {
        let finalTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let doc = InstructionDocument(
            title: finalTitle.isEmpty ? "Untitled Pattern" : finalTitle,
            fileData: importedFile.data,
            fileType: importedFile.fileType,
            subjectTags: Array(selectedSubjectTags),
            projectTags: Array(selectedProjectTags),
            coverImageData: customCoverData
        )
        modelContext.insert(doc)
        dismiss()
    }
}

// MARK: - Reusable tag picker row

struct TagPickerRow: View {
    let tags: [String]
    @Binding var selected: Set<String>
    let onAddTap: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    let isOn = selected.contains(tag)
                    Button {
                        if isOn { selected.remove(tag) } else { selected.insert(tag) }
                    } label: {
                        Text(tag)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(isOn ? Color.accentColor : Color(.secondarySystemBackground))
                            .foregroundStyle(isOn ? .white : .primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Button(action: onAddTap) {
                    Image(systemName: "plus")
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Import option card

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
                Text(title).font(.headline)
                Text(description).font(.subheadline).foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
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
