//
//  ContentView.swift
//  Yarn&Yarn
//
//  Created by Yangyang Long on 3/16/26.
//

import SwiftUI
import SwiftData
import PhotosUI
import PDFKit

// MARK: - Root view

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \InstructionDocument.createdDate, order: .reverse)
    private var documents: [InstructionDocument]

    @State private var showingImportView = false
    @State private var showingGlossary = false
    @State private var documentToEdit: InstructionDocument?

    var body: some View {
        NavigationStack {
            Group {
                if documents.isEmpty {
                    ContentUnavailableView {
                        Label("No Patterns", systemImage: "doc.text.image")
                    } description: {
                        Text("Import your first knitting or crocheting pattern to get started")
                    } actions: {
                        Button {
                            showingImportView = true
                        } label: {
                            Label("Import Pattern", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    ScrollView {
                        LazyVGrid(
                            columns: [GridItem(.flexible()), GridItem(.flexible())],
                            spacing: 16
                        ) {
                            ForEach(documents) { document in
                                NavigationLink(value: document) {
                                    DocumentCardView(document: document)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Edit Info", systemImage: "pencil") {
                                        documentToEdit = document
                                    }
                                    Divider()
                                    Button("Delete", systemImage: "trash", role: .destructive) {
                                        modelContext.delete(document)
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Yarn & Yarn")
            .navigationDestination(for: InstructionDocument.self) { doc in
                DocumentViewerView(document: doc)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingGlossary = true
                    } label: {
                        Label("Glossary", systemImage: "book.closed")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingImportView = true
                    } label: {
                        Label("Import Pattern", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingImportView) {
                DocumentImportView()
            }
            .sheet(isPresented: $showingGlossary) {
                GlossaryBrowserView()
            }
            .sheet(item: $documentToEdit) { doc in
                DocumentEditSheet(document: doc)
            }
        }
    }
}

// MARK: - Card view

struct DocumentCardView: View {
    let document: InstructionDocument
    @State private var thumbnail: UIImage?

    var allTags: [String] { document.subjectTags + document.projectTags }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cover image
            ZStack {
                Color(.secondarySystemBackground)
                if let img = thumbnail {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: document.isPDF ? "doc.fill" : "photo.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                }
            }
            .aspectRatio(3 / 4, contentMode: .fill)
            .clipped()

            // Info
            VStack(alignment: .leading, spacing: 6) {
                Text(document.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                if !allTags.isEmpty {
                    TagChipRow(tags: allTags, maxVisible: 3)
                }
            }
            .padding(10)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
        .task(id: document.id) {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        if let data = document.coverImageData, let img = UIImage(data: data) {
            thumbnail = img
            return
        }
        if document.isPDF,
           let pdf = PDFDocument(data: document.fileData),
           let page = pdf.page(at: 0) {
            thumbnail = page.thumbnail(of: CGSize(width: 300, height: 420), for: .mediaBox)
        } else if document.isImage {
            thumbnail = UIImage(data: document.fileData)
        }
    }
}

// MARK: - Tag display chip row

struct TagChipRow: View {
    let tags: [String]
    let maxVisible: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tags.prefix(maxVisible), id: \.self) { tag in
                Text(tag)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.12))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(Capsule())
            }
            if tags.count > maxVisible {
                Text("+\(tags.count - maxVisible)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Edit sheet

struct DocumentEditSheet: View {
    @Bindable var document: InstructionDocument
    @Environment(\.dismiss) private var dismiss

    @State private var coverPhotoItem: PhotosPickerItem?
    @State private var generatedCoverImage: UIImage?

    @AppStorage("customSubjectTags") private var customSubjectTagsRaw = ""
    @AppStorage("customProjectTags") private var customProjectTagsRaw = ""

    @State private var showingAddSubjectTag = false
    @State private var showingAddProjectTag = false
    @State private var newTagName = ""

    var allSubjectTags: [String] {
        subjectTagPresets + customSubjectTagsRaw
            .split(separator: ",").map(String.init).filter { !$0.isEmpty }
    }

    var allProjectTags: [String] {
        projectTagPresets + customProjectTagsRaw
            .split(separator: ",").map(String.init).filter { !$0.isEmpty }
    }

    var coverImage: UIImage? {
        if let data = document.coverImageData { return UIImage(data: data) }
        return generatedCoverImage
    }

    // Bindings backed by the document's tag arrays
    @State private var selectedSubjectTags: Set<String> = []
    @State private var selectedProjectTags: Set<String> = []

    var body: some View {
        NavigationStack {
            Form {
                // Cover
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
                                if let data = try? await item?.loadTransferable(type: Data.self) {
                                    document.coverImageData = data
                                }
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                }

                Section("Pattern Name") {
                    TextField("Pattern name", text: $document.title)
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
            .navigationTitle("Edit Pattern")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        document.subjectTags = Array(selectedSubjectTags)
                        document.projectTags = Array(selectedProjectTags)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .task { await loadGeneratedCover() }
            .onAppear {
                selectedSubjectTags = Set(document.subjectTags)
                selectedProjectTags = Set(document.projectTags)
            }
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

    private func loadGeneratedCover() async {
        guard document.coverImageData == nil else { return }
        if document.isPDF,
           let pdf = PDFDocument(data: document.fileData),
           let page = pdf.page(at: 0) {
            generatedCoverImage = page.thumbnail(
                of: CGSize(width: 400, height: 560), for: .mediaBox
            )
        } else if document.isImage {
            generatedCoverImage = UIImage(data: document.fileData)
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
}

#Preview {
    ContentView()
        .modelContainer(for: InstructionDocument.self, inMemory: true)
}
