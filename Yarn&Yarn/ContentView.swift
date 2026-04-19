//
//  ContentView.swift
//  Yarn&Yarn
//

import SwiftUI
import SwiftData
import PhotosUI
import PDFKit

// MARK: - Root

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \InstructionDocument.createdDate, order: .reverse) private var documents: [InstructionDocument]
    @Query(sort: \KnittingProject.startDate, order: .reverse)       private var projects:  [KnittingProject]

    enum Tab { case library, project }
    enum LibraryLayout { case card, list }

    @State private var selectedTab:    Tab           = .project
    @State private var libraryLayout:  LibraryLayout = .card
    @State private var librarySearch:  String        = ""
    @State private var showingImport     = false
    @State private var showingNewProject = false
    @State private var documentToEdit:  InstructionDocument? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ── Top control bar ──────────────────────────────────────
                HStack(spacing: 12) {
                    Picker("Tab", selection: $selectedTab) {
                        Text("Library").tag(Tab.library)
                        Text("Project").tag(Tab.project)
                    }
                    .pickerStyle(.segmented)

                    if selectedTab == .library {
                        Picker("Layout", selection: $libraryLayout) {
                            HeroIcon(.squaresGrid, size: 16).tag(LibraryLayout.card)
                            HeroIcon(.listBullet, size: 16).tag(LibraryLayout.list)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 80)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .animation(.spring(response: 0.3), value: selectedTab)

                // ── Search bar (library only) ────────────────────────────
                if selectedTab == .library {
                    HStack(spacing: 8) {
                        HeroIcon(.magnifyingGlass, size: 14)
                            .foregroundStyle(.secondary)
                        TextField("Search patterns", text: $librarySearch)
                            .font(.subheadline)
                            .autocorrectionDisabled()
                            .submitLabel(.search)
                        if !librarySearch.isEmpty {
                            Button {
                                librarySearch = ""
                            } label: {
                                HeroIcon(.xCircle, size: 16)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Divider()

                // ── Swipeable tab content ────────────────────────────────
                TabView(selection: $selectedTab) {
                    LibraryTabView(
                        documents: documents,
                        layout: libraryLayout,
                        searchText: librarySearch,
                        onEdit:   { documentToEdit = $0 },
                        onDelete: { modelContext.delete($0); try? modelContext.save() }
                    )
                    .tag(Tab.library)

                    ProjectTabView(
                        projects:  projects,
                        onDelete: { modelContext.delete($0); try? modelContext.save() }
                    )
                    .tag(Tab.project)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                // Reserve space at the bottom so scroll content clears the FAB
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    Color.clear.frame(height: 88)
                }
            }
            // ── Floating action button ────────────────────────────────
            .overlay(alignment: .bottom) {
                Button {
                    switch selectedTab {
                    case .library:  showingImport = true
                    case .project:  showingNewProject = true
                    }
                } label: {
                    HStack(spacing: 8) {
                        HeroIcon(.plus, size: 15)
                        Text(selectedTab == .library ? "Upload Pattern" : "Start a project")
                            .font(DesignTokens.Typography.display(DesignTokens.Typography.sizeMD, weight: DesignTokens.Typography.Weight.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Color.accentColor))
                    .shadow(color: Color.accentColor.opacity(0.35), radius: 12, y: 5)
                }
                .animation(.spring(response: 0.3), value: selectedTab)
                .padding(.bottom, 24)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            // ── Navigation destinations ───────────────────────────────
            .navigationDestination(for: InstructionDocument.self) { doc in
                LibraryPatternView(document: doc)
            }
            .navigationDestination(for: KnittingProject.self) { project in
                if let pattern = project.pattern {
                    DocumentViewerView(document: pattern, project: project)
                } else {
                    ContentUnavailableView(
                        "Pattern Not Found",
                        systemImage: "doc.text.image.fill",
                        description: Text("The pattern for this project has been deleted from your library.")
                    )
                }
            }
            // ── Sheets ───────────────────────────────────────────────
            .sheet(isPresented: $showingImport)      { DocumentImportView() }
            .sheet(isPresented: $showingNewProject)  { NewProjectSheet() }
            .sheet(item: $documentToEdit)            { DocumentEditSheet(document: $0) }
        }
    }
}

// MARK: - Library Tab

struct LibraryTabView: View {
    let documents:  [InstructionDocument]
    let layout:     ContentView.LibraryLayout
    let searchText: String
    let onEdit:    (InstructionDocument) -> Void
    let onDelete:  (InstructionDocument) -> Void

    private var filteredDocuments: [InstructionDocument] {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return documents }
        let q = searchText.lowercased()
        return documents.filter {
            $0.title.lowercased().contains(q) ||
            $0.subjectTags.contains { $0.lowercased().contains(q) } ||
            $0.projectTags.contains  { $0.lowercased().contains(q) }
        }
    }

    var body: some View {
        Group {
            if documents.isEmpty {
                ContentUnavailableView {
                    Label("No Patterns", systemImage: "doc.text.image")
                } description: {
                    Text("Import your first knitting or crochet pattern to get started.")
                }
            } else if filteredDocuments.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                switch layout {
                case .card:  cardView
                case .list:  listView
                }
            }
        }
    }

    // ── Masonry card grid ────────────────────────────────────────────
    private var cardView: some View {
        ScrollView(.vertical) {
            HStack(alignment: .top, spacing: 12) {
                masonryColumn(parity: 0)
                masonryColumn(parity: 1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    @ViewBuilder
    private func masonryColumn(parity: Int) -> some View {
        let visible = filteredDocuments
        VStack(spacing: 12) {
            ForEach(visible.indices.filter { $0 % 2 == parity }, id: \.self) { i in
                let doc = visible[i]
                NavigationLink(value: doc) {
                    DocumentCardView(document: doc)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Edit Info", systemImage: "pencil") { onEdit(doc) }
                    Divider()
                    Button("Delete", systemImage: "trash", role: .destructive) { onDelete(doc) }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    // ── List view ────────────────────────────────────────────────────
    private var listView: some View {
        ScrollView(.vertical) {
            VStack(spacing: 8) {
                ForEach(filteredDocuments) { doc in
                    NavigationLink(value: doc) {
                        DocumentListRowView(document: doc)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Edit Info", systemImage: "pencil") { onEdit(doc) }
                        Divider()
                        Button("Delete", systemImage: "trash", role: .destructive) { onDelete(doc) }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Project Tab

struct ProjectTabView: View {
    let projects:  [KnittingProject]
    let onDelete: (KnittingProject) -> Void

    @State private var projectToEdit: KnittingProject? = nil

    var body: some View {
        if projects.isEmpty {
            ContentUnavailableView {
                Label("No Projects", systemImage: "tray")
            } description: {
                Text("Tap + to start a new knitting or crochet project.")
            }
        } else {
            ScrollView(.vertical) {
                VStack(spacing: 8) {
                    ForEach(projects) { project in
                        NavigationLink(value: project) {
                            ProjectRowView(project: project)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Edit Project Info", systemImage: "pencil") {
                                projectToEdit = project
                            }
                            // Quick status change
                            Menu("Set Status", systemImage: "circle.lefthalf.filled") {
                                ForEach(KnittingProject.Status.allCases, id: \.self) { s in
                                    Button {
                                        project.status = s
                                    } label: {
                                        Label(s.rawValue, systemImage: s.icon)
                                    }
                                }
                            }
                            Divider()
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                onDelete(project)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .sheet(item: $projectToEdit) { proj in
                ProjectEditSheet(project: proj)
            }
        }
    }
}

// MARK: - Document card (card layout)

struct DocumentCardView: View {
    let document: InstructionDocument
    @State private var thumbnail: UIImage?

    var allTags: [String] { document.subjectTags + document.projectTags }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Color(.secondarySystemBackground)
                .aspectRatio(3 / 4, contentMode: .fit)
                .overlay {
                    if let img = thumbnail {
                        Image(uiImage: img).resizable().scaledToFill()
                    } else {
                        HeroIcon(document.isPDF ? .documentFilled : .photoFilled, size: 36)
                            .foregroundStyle(.tertiary)
                    }
                }
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Text(document.title)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)
                .foregroundStyle(.primary)

            if !allTags.isEmpty {
                TagChipRow(tags: allTags, maxVisible: 3)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemBackground)))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
        .task(id: document.id) { await loadThumbnail() }
    }

    private func loadThumbnail() async {
        if let data = document.coverImageData, let img = UIImage(data: data) {
            thumbnail = img; return
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

// MARK: - Document list row (list layout)

struct DocumentListRowView: View {
    let document: InstructionDocument
    @State private var thumbnail: UIImage?

    var allTags: [String] { document.subjectTags + document.projectTags }

    var body: some View {
        HStack(spacing: 12) {
            // Small portrait thumbnail
            Color(.secondarySystemBackground)
                .frame(width: 48, height: 64)
                .overlay {
                    if let img = thumbnail {
                        Image(uiImage: img).resizable().scaledToFill()
                    } else {
                        HeroIcon(document.isPDF ? .documentFilled : .photoFilled, size: 18)
                            .foregroundStyle(.tertiary)
                    }
                }
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(document.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                if !allTags.isEmpty {
                    TagChipRow(tags: allTags, maxVisible: 2)
                }

                Text(document.createdDate.formatted(.dateTime.month(.abbreviated).day().year()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HeroIcon(.chevronRight, size: 12)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .task(id: document.id) { await loadThumbnail() }
    }

    private func loadThumbnail() async {
        if let data = document.coverImageData, let img = UIImage(data: data) {
            thumbnail = img; return
        }
        if document.isPDF,
           let pdf = PDFDocument(data: document.fileData),
           let page = pdf.page(at: 0) {
            thumbnail = page.thumbnail(of: CGSize(width: 150, height: 200), for: .mediaBox)
        } else if document.isImage {
            thumbnail = UIImage(data: document.fileData)
        }
    }
}

// MARK: - Project list row

struct ProjectRowView: View {
    let project: KnittingProject
    @State private var thumbnail: UIImage?

    var body: some View {
        HStack(spacing: 12) {
            // Portrait thumbnail (project cover > pattern cover > PDF page 0)
            Color(.secondarySystemBackground)
                .frame(width: 48, height: 64)
                .overlay {
                    if let img = thumbnail {
                        Image(uiImage: img).resizable().scaledToFill()
                    } else {
                        Image(systemName: "doc.text")
                            .foregroundStyle(.tertiary)
                    }
                }
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(project.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                // Show pattern name only when the project has a custom name
                if let pattern = project.pattern,
                   !project.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(pattern.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(project.startDate.formatted(.dateTime.month(.abbreviated).day().year()))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Progress bar — shown only after "I'm Here" marker has been set
                if let pct = rowReadingProgress {
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.secondary.opacity(0.18))
                            Capsule()
                                .fill(Color.accentColor)
                                .frame(width: g.size.width * pct)
                        }
                    }
                    .frame(height: 4)
                    .padding(.top, 2)
                }
            }

            Spacer()

            HeroIcon(.chevronRight, size: 12)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .task(id: project.id) { await loadThumbnail() }
    }

    /// 1-column progress approximation (full column analysis is only available inside the PDF viewer).
    private var rowReadingProgress: Double? {
        guard project.hasReadingPosition,
              let fileData = project.pattern?.fileData,
              let pdf = PDFDocument(data: fileData),
              pdf.pageCount > 0 else { return nil }
        let total = pdf.pageCount
        let withinPage = 1.0 - project.readingPositionY   // Y: bottom=0, top=1
        return min(1.0, (Double(project.readingPositionPage) + withinPage) / Double(total))
    }

    private func loadThumbnail() async {
        // Priority: project cover → pattern cover → PDF first page
        if let data = project.coverImageData, let img = UIImage(data: data) {
            thumbnail = img; return
        }
        if let data = project.pattern?.coverImageData, let img = UIImage(data: data) {
            thumbnail = img; return
        }
        if let fileData = project.pattern?.fileData,
           let pdf = PDFDocument(data: fileData),
           let page = pdf.page(at: 0) {
            thumbnail = page.thumbnail(of: CGSize(width: 150, height: 200), for: .mediaBox)
        }
    }
}

// MARK: - Library pattern viewer (read-only, no glossary / counter)

struct LibraryPatternView: View {
    let document: InstructionDocument
    @State private var showingCreateProject = false
    @State private var showingEditSheet     = false

    var body: some View {
        ZStack {
            // ── Pattern content ──────────────────────────────────────
            if document.isPDF {
                LibraryPDFView(data: document.fileData)
                    .ignoresSafeArea(edges: .bottom)
            } else if let image = UIImage(data: document.fileData) {
                ScrollView([.vertical, .horizontal]) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingEditSheet = true
                } label: {
                    HeroIcon(.pencilSquare)
                }
            }
        }
        // ── Create Project FAB ───────────────────────────────────────
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack {
                Spacer()
                Button {
                    showingCreateProject = true
                } label: {
                    HStack(spacing: 8) {
                        HeroIcon(.plus, size: 15)
                        Text("Create Project")
                            .font(DesignTokens.Typography.display(DesignTokens.Typography.sizeMD, weight: DesignTokens.Typography.Weight.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Color.accentColor))
                    .shadow(color: Color.accentColor.opacity(0.35), radius: 12, y: 5)
                }
                Spacer()
            }
            .padding(.bottom, 24)
            .background(.clear)
        }
        .sheet(isPresented: $showingCreateProject) {
            NewProjectSheet(preselectedPattern: document)
        }
        .sheet(isPresented: $showingEditSheet) {
            DocumentEditSheet(document: document)
        }
    }
}

/// Bare-bones PDFView wrapper — scroll, zoom, no overlays.
struct LibraryPDFView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.document = PDFDocument(data: data)
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .systemBackground
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}

// MARK: - New Project Sheet

struct NewProjectSheet: View {
    /// When launched from LibraryPatternView the pattern is pre-selected.
    var preselectedPattern: InstructionDocument? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \InstructionDocument.createdDate, order: .reverse)
    private var documents: [InstructionDocument]

    @State private var projectName = ""
    @State private var selectedID: UUID? = nil
    @State private var startDate   = Date()
    @State private var status      = KnittingProject.Status.notStarted

    private var selectedPattern: InstructionDocument? {
        documents.first { $0.id == selectedID }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Pattern picker
                Section {
                    if let fixed = preselectedPattern {
                        // Launched from the library viewer — pattern is locked
                        HStack {
                            Text(fixed.title)
                            Spacer()
                            HeroIcon(.lockClosedFilled, size: 12)
                                .foregroundStyle(.secondary)
                        }
                    } else if documents.isEmpty {
                        Text("No patterns in library — import one first.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Pattern", selection: $selectedID) {
                            Text("Select a pattern…").tag(Optional<UUID>.none)
                            ForEach(documents) { doc in
                                Text(doc.title).tag(Optional(doc.id))
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }
                } header: {
                    Text("Pattern")
                } footer: {
                    Text("A project is tied to one pattern. The same pattern can be used for multiple projects.")
                }

                Section("Project Name") {
                    TextField("Optional — defaults to pattern name", text: $projectName)
                }

                Section("Details") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)

                    Picker("Status", selection: $status) {
                        ForEach(KnittingProject.Status.allCases, id: \.self) { s in
                            Label(s.rawValue, systemImage: s.icon).tag(s)
                        }
                    }
                }
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Pre-seed when launched from a library pattern view
                if let p = preselectedPattern { selectedID = p.id }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { createProject() }
                        .fontWeight(.semibold)
                        .disabled(selectedID == nil)
                }
            }
        }
    }

    private func createProject() {
        let project = KnittingProject(
            name:      projectName,
            pattern:   selectedPattern,
            startDate: startDate,
            status:    status
        )
        modelContext.insert(project)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Tag chip row

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

// MARK: - Document edit sheet

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

    @State private var selectedSubjectTags: Set<String> = []
    @State private var selectedProjectTags: Set<String> = []

    var body: some View {
        NavigationStack {
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
                    TagPickerRow(tags: allSubjectTags, selected: $selectedSubjectTags, onAddTap: { showingAddSubjectTag = true })
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                } header: { Text("Subject (Optional)") }

                Section {
                    TagPickerRow(tags: allProjectTags, selected: $selectedProjectTags, onAddTap: { showingAddProjectTag = true })
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                } header: { Text("Project Type (Optional)") }
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
            Image(uiImage: img).resizable().scaledToFill()
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
            generatedCoverImage = page.thumbnail(of: CGSize(width: 400, height: 560), for: .mediaBox)
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

// MARK: - Project edit sheet

struct ProjectEditSheet: View {
    @Bindable var project: KnittingProject
    @Environment(\.dismiss) private var dismiss

    @State private var coverPhotoItem: PhotosPickerItem?
    @State private var localCoverImage: UIImage?

    private var displayedCover: UIImage? {
        if let data = project.coverImageData { return UIImage(data: data) }
        if let data = project.pattern?.coverImageData { return UIImage(data: data) }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        // Cover preview
                        Group {
                            if let img = localCoverImage ?? displayedCover {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Color(.secondarySystemBackground)
                                    .overlay {
                                        Image(systemName: "photo")
                                            .font(.system(size: 44))
                                            .foregroundStyle(.tertiary)
                                    }
                            }
                        }
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
                                    project.coverImageData = data
                                    localCoverImage = UIImage(data: data)
                                }
                            }
                        }

                        if project.coverImageData != nil {
                            Button(role: .destructive) {
                                project.coverImageData = nil
                                localCoverImage = nil
                            } label: {
                                Label("Remove Custom Cover", systemImage: "trash")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                }

                Section("Project Name") {
                    TextField("Optional — defaults to pattern name", text: $project.name)
                }

                if let pattern = project.pattern {
                    Section("Pattern") {
                        HStack {
                            Text(pattern.title)
                            Spacer()
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Edit Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .modelContainer(for: [InstructionDocument.self, Marker.self, KnittingProject.self], inMemory: true)
}
