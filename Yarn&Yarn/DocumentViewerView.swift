//
//  DocumentViewerView.swift
//  Yarn&Yarn
//
//  Created by Yangyang Long on 3/16/26.
//

import SwiftUI
import PDFKit
import SwiftData

enum ActiveTab { case glossary, counter, marker }

struct DocumentViewerView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var document: InstructionDocument
    /// When opened from the Project tab, the associated project is passed in so the
    /// view can show the project name and let the user update its status.
    @Bindable var project: KnittingProject

    @State private var selectedTerminology: String?
    @State private var showingTerminologyPopover = false
    @State private var isDraggingMarker = false
    @State private var draggingMarkerType: Marker.MarkerType?
    @State private var newMarkerPosition: CGPoint?
    @StateObject private var lensBridge = LensBridge()
    @State private var activeTab: ActiveTab? = nil
    @State private var lensPosition: CGPoint = .zero
    @State private var lensDragAnchor: CGPoint = .zero       // lens center at gesture start
    @State private var lastDragStart: CGPoint = .zero        // v.startLocation of current gesture
    @State private var lensTerms: [(term: KnittingGlossary.Term, screenRect: CGRect)] = []
    @State private var showingGlossary = false
    @State private var currentPage: Int                      // seeded from project.lastReadPage
    @State private var showingTextReader = false
    @State private var showingEditSheet = false
    @State private var showingProjectEditSheet = false
    @State private var counterToEdit: Marker?
    @State private var visibleCounterIDs: Set<UUID> = []
    @State private var viewportCenter: CGPoint = CGPoint(x: 0.5, y: 0.5)

    init(document: InstructionDocument, project: KnittingProject) {
        self._document = Bindable(document)
        self._project  = Bindable(project)
        self._currentPage = State(initialValue: project.lastReadPage)
    }

    private var lensActive: Bool { activeTab == .glossary }

    private var counterMarkers: [Marker] {
        document.markers
            .filter { $0.type == .counter }
            .filter { visibleCounterIDs.contains($0.id) }
            .sorted { lhs, rhs in
                if lhs.pageNumber != rhs.pageNumber {
                    return lhs.pageNumber < rhs.pageNumber
                }
                // Higher positionY = visually higher on screen (PDF Y is bottom-up)
                if abs(lhs.positionY - rhs.positionY) > 0.02 {
                    return lhs.positionY > rhs.positionY
                }
                return lhs.positionX < rhs.positionX
            }
    }

    var body: some View {
        ZStack {
            // Document display with markers embedded
            if document.isPDF {
                if showingTextReader {
                    // Text reader mode - read-only text view
                    if let pdfDocument = PDFDocument(data: document.fileData) {
                        TextReaderView(pdfDocument: pdfDocument)
                    }
                } else {
                    // PDF viewer mode - with markers and lens
                    NativePDFDocumentView(
                        pdfData: document.fileData,
                        document: document,
                        lensBridge: lensBridge,
                        currentPage: $currentPage,
                        visibleCounterIDs: $visibleCounterIDs,
                        viewportCenter: $viewportCenter,
                        hasReadingPosition: project.hasReadingPosition,
                        isReadingMarkerVisible: activeTab == .marker,
                        readingPositionPage: project.readingPositionPage,
                        readingPositionX: project.readingPositionX,
                        readingPositionY: project.readingPositionY,
                        onReadingPositionMoved: { page, x, y in
                            project.readingPositionPage = page
                            project.readingPositionX    = x
                            project.readingPositionY    = y
                            project.hasReadingPosition  = true
                            try? modelContext.save()
                        }
                    )
                }
            } else {
                ImageDocumentView(imageData: document.fileData, document: document, highlightingEnabled: false)
            }

            // MARK: - Lens Overlay
            if lensActive && !showingTextReader && document.isPDF {
                GeometryReader { geo in
                    // Lens: transparent circle with highlight rects inside, border ring only
                    ZStack {
                        ForEach(lensTerms.indices, id: \.self) { i in
                            let info = lensTerms[i]
                            let isFocused = i == 0
                            RoundedRectangle(cornerRadius: 3)
                                // Focused term: orange; others: soft yellow
                                .fill(isFocused
                                      ? Color.orange.opacity(0.7)
                                      : Color.yellow.opacity(0.45))
                                .frame(width: info.screenRect.width,
                                       height: info.screenRect.height)
                                .offset(
                                    x: info.screenRect.midX - lensPosition.x,
                                    y: info.screenRect.midY - lensPosition.y
                                )
                        }
                    }
                    .frame(width: 200, height: 200)
                    .clipShape(Circle())
                    .contentShape(Circle())
                    .overlay { Circle().strokeBorder(Color.accentColor.opacity(0.7), lineWidth: 2) }
                    .position(lensPosition)
                    // .simultaneousGesture lets the UIKit PDFView pinch-to-zoom recognizer
                    // fire at the same time as the lens drag — without it, touches on the
                    // circle area would exclusively block the underlying PDFView gestures.
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { v in
                                // Detect new gesture by comparing startLocation; preserve the
                                // initial offset between finger and lens center so the circle
                                // doesn't jump to center under the finger.
                                if v.startLocation != lastDragStart {
                                    lensDragAnchor = lensPosition
                                    lastDragStart = v.startLocation
                                }
                                lensPosition = CGPoint(
                                    x: lensDragAnchor.x + v.translation.width,
                                    y: lensDragAnchor.y + v.translation.height
                                )
                                refreshLensTerms()
                            }
                    )
                    .onAppear {
                        if lensPosition == .zero {
                            lensPosition = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                            refreshLensTerms()
                        }
                    }
                    .onChange(of: viewportCenter) {
                        refreshLensTerms()
                    }
                }
            }
        }
        .onGeometryChange(for: CGPoint.self) { $0.frame(in: .global).origin } action: {
            lensBridge.lensOriginInWindow = $0
        }
        .onChange(of: currentPage) {
            project.lastReadPage = currentPage
            try? modelContext.save()
        }
        .onChange(of: activeTab) {
            // Auto-place the marker the first time the user opens the tab
            if activeTab == .marker && !project.hasReadingPosition {
                markMyPosition()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !showingTextReader {
                VStack(spacing: 0) {
                    if activeTab == .glossary {
                        Divider()
                        GlossaryPanelView(lensTerms: lensTerms)
                    } else if activeTab == .counter {
                        Divider()
                        CounterPanelView(
                            counters: counterMarkers,
                            onEdit: { counterToEdit = $0 },
                            onDelete: { marker in
                                modelContext.delete(marker)
                                try? modelContext.save()
                            },
                            onAddCounter: addCounter
                        )
                    } else if activeTab == .marker {
                        Divider()
                        MarkerPanelView(
                            hasMarker: project.hasReadingPosition,
                            onRefresh: markMyPosition
                        )
                    }
                    Divider()
                    DocumentToolbarTabs(activeTab: $activeTab, isPDF: document.isPDF)
                }
                .background(.bar)
            }
        }
        .sheet(item: $counterToEdit) { counter in
            CounterEditSheet(counter: counter)
                .presentationDetents([.medium])
        }
        .navigationTitle(project.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Text reader toggle (only for PDFs)
            if document.isPDF {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation {
                            showingTextReader.toggle()
                        }
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                    } label: {
                        Label(
                            showingTextReader ? "PDF View" : "Text Reader",
                            systemImage: showingTextReader ? "doc.richtext" : "book.pages"
                        )
                    }
                }
            }

            // Reading progress (replaces status pill)
            ToolbarItem(placement: .principal) {
                if let pct = readingProgress {
                    HStack(spacing: 6) {
                        // Mini progress bar
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.secondary.opacity(0.2))
                                Capsule().fill(Color.accentColor)
                                    .frame(width: g.size.width * pct)
                            }
                        }
                        .frame(width: 56, height: 5)
                        Text("\(Int(pct * 100))%")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                } else {
                    // No marker set yet — show project title subtitle
                    Text(project.displayName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Menu {
                    // Status
                    Menu("Status: \(project.status.rawValue)", systemImage: project.status.icon) {
                        ForEach(KnittingProject.Status.allCases, id: \.self) { s in
                            Button {
                                project.status = s
                                try? modelContext.save()
                            } label: {
                                Label(s.rawValue, systemImage: s.icon)
                            }
                        }
                    }

                    Divider()

                    Button {
                        showingGlossary = true
                    } label: {
                        Label("View Glossary", systemImage: "book.closed")
                    }

                    Button {
                        showingEditSheet = true
                    } label: {
                        Label("Edit Pattern Info", systemImage: "pencil")
                    }

                    Button {
                        showingProjectEditSheet = true
                    } label: {
                        Label("Edit Project Info", systemImage: "folder.badge.person.crop")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingGlossary) {
            GlossaryBrowserView()
        }
        .sheet(isPresented: $showingEditSheet) {
            DocumentEditSheet(document: document)
        }
        .sheet(isPresented: $showingProjectEditSheet) {
            ProjectEditSheet(project: project)
        }
    }
    
    private func addNoteMarker(at position: CGPoint) {
        let newMarker = Marker.noteMarker(
            note: "New note",
            positionX: position.x,
            positionY: position.y,
            pageNumber: currentPage
        )
        newMarker.document = document
        document.markers.append(newMarker)
        modelContext.insert(newMarker)
        try? modelContext.save()
    }
    
    private let counterColorPool = [
        "sage", "mauve", "terracotta", "steel", "gold", "lavender",
        "forest", "rose", "slate", "amber", "plum", "linen"
    ]

    private func addCounter() {
        let n = document.markers.filter { $0.type == .counter }.count
        let newMarker = Marker.counterMarker(
            label: "Counter \(n + 1)",
            targetCount: 0,
            positionX: viewportCenter.x,
            positionY: viewportCenter.y,
            pageNumber: currentPage,
            color: counterColorPool.randomElement() ?? "green"
        )
        newMarker.document = document
        document.markers.append(newMarker)
        modelContext.insert(newMarker)
        try? modelContext.save()
        // Immediately mark the new counter as visible so the panel row appears
        // right away. The CADisplayLink will confirm/correct visibility on the next frame.
        visibleCounterIDs.insert(newMarker.id)
        withAnimation(.spring(response: 0.3)) { activeTab = .counter }
    }

    // MARK: - Lens helpers

    // MARK: - "I am here" marker

    private func markMyPosition() {
        project.readingPositionPage = currentPage
        project.readingPositionX    = viewportCenter.x
        project.readingPositionY    = viewportCenter.y
        project.hasReadingPosition  = true
        try? modelContext.save()
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }

    /// 0–1 progress through the document, accounting for 1- or 2-column layout.
    private var readingProgress: Double? {
        guard project.hasReadingPosition,
              let pdf = PDFDocument(data: document.fileData),
              pdf.pageCount > 0 else { return nil }
        let total = pdf.pageCount
        let columnCount = lensBridge.detectColumnCount?(project.readingPositionPage) ?? 1
        let x = project.readingPositionX
        let y = project.readingPositionY  // 0 = page bottom, 1 = page top
        let withinPage: Double
        if columnCount == 2 {
            // Left column = first half of page progress; right column = second half
            withinPage = x < 0.5 ? (1 - y) * 0.5 : 0.5 + (1 - y) * 0.5
        } else {
            withinPage = 1 - y
        }
        return min(1.0, (Double(project.readingPositionPage) + withinPage) / Double(total))
    }

    private func refreshLensTerms() {
        let radius: CGFloat = 100
        let origin = lensBridge.lensOriginInWindow
        // Convert lens position from SwiftUI local space → UIKit window space
        let centerInWindow = CGPoint(x: origin.x + lensPosition.x, y: origin.y + lensPosition.y)
        let raw = lensBridge.queryTermsAt?(centerInWindow, radius) ?? []
        // Convert returned window-space rects back to SwiftUI local space for rendering
        lensTerms = raw
            .map { (term: $0.0, screenRect: CGRect(x: $0.1.origin.x - origin.x,
                                                   y: $0.1.origin.y - origin.y,
                                                   width: $0.1.width, height: $0.1.height)) }
            .sorted { a, b in
                let da = hypot(a.screenRect.midX - lensPosition.x, a.screenRect.midY - lensPosition.y)
                let db = hypot(b.screenRect.midX - lensPosition.x, b.screenRect.midY - lensPosition.y)
                return da < db
            }
    }

}

// MARK: - Native PDF Document View
struct NativePDFDocumentView: View {
    let pdfData: Data
    @Bindable var document: InstructionDocument
    let lensBridge: LensBridge
    @Binding var currentPage: Int
    var visibleCounterIDs: Binding<Set<UUID>>
    var viewportCenter: Binding<CGPoint>
    var hasReadingPosition: Bool
    var isReadingMarkerVisible: Bool
    var readingPositionPage: Int
    var readingPositionX: Double
    var readingPositionY: Double
    var onReadingPositionMoved: ((Int, Double, Double) -> Void)?

    // Stored in @State so the PDFDocument object is created once and remains
    // stable across re-renders. Without this, body creates a new PDFDocument
    // on every render, which changes the .id() on NativePDFKitView and causes
    // it to be destroyed and rebuilt (resetting the scroll position to page 1).
    @State private var pdfDocument: PDFDocument?

    var body: some View {
        Group {
            if let pdfDocument = pdfDocument {
                NativePDFReaderView(
                    pdfDocument: pdfDocument,
                    document: document,
                    lensBridge: lensBridge,
                    currentPage: $currentPage,
                    visibleCounterIDs: visibleCounterIDs,
                    viewportCenter: viewportCenter,
                    hasReadingPosition: hasReadingPosition,
                    isReadingMarkerVisible: isReadingMarkerVisible,
                    readingPositionPage: readingPositionPage,
                    readingPositionX: readingPositionX,
                    readingPositionY: readingPositionY,
                    onReadingPositionMoved: onReadingPositionMoved
                )
            } else {
                Text("Unable to load PDF")
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: pdfData) {
            pdfDocument = PDFDocument(data: pdfData)
        }
    }
}

// MARK: - PDF Document View (Old - kept for reference)
struct PDFDocumentView: View {
    let pdfData: Data
    @Bindable var document: InstructionDocument
    let highlightingEnabled: Bool
    
    @State private var selectedTerm: KnittingGlossary.Term?
    @State private var showingTermDetail = false
    @State private var selectedMarker: Marker?
    @State private var showingCounterPopup = false
    
    var body: some View {
        if let pdfDocument = PDFDocument(data: pdfData) {
            PDFKitView(
                pdfDocument: pdfDocument,
                document: document,
                highlightingEnabled: highlightingEnabled,
                selectedTerm: $selectedTerm,
                showingTermDetail: $showingTermDetail,
                selectedMarker: $selectedMarker,
                showingCounterPopup: $showingCounterPopup
            )
            .sheet(isPresented: $showingTermDetail) {
                if let selectedTerm {
                    GlossaryTermDetailView(term: selectedTerm)
                        .presentationDetents([.medium, .large])
                }
            }
            // Counter popup removed — counting happens in the bottom toolbar panel
        } else {
            Text("Unable to load PDF")
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - PDFKit Integration
struct PDFKitView: UIViewRepresentable {
    let pdfDocument: PDFDocument
    @Bindable var document: InstructionDocument
    let highlightingEnabled: Bool
    @Binding var selectedTerm: KnittingGlossary.Term?
    @Binding var showingTermDetail: Bool
    @Binding var selectedMarker: Marker?
    @Binding var showingCounterPopup: Bool
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = pdfDocument
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.backgroundColor = .systemBackground
        
        // Enable text selection for highlighting
        pdfView.isUserInteractionEnabled = true
        
        // Set up highlighter
        let highlighter = PDFTextHighlighter(pdfView: pdfView)
        context.coordinator.highlighter = highlighter
        
        // Add tap gesture recognizer
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tapGesture.delegate = context.coordinator
        pdfView.addGestureRecognizer(tapGesture)
        
        // Add long press gesture for options menu
        let longPressGesture = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        longPressGesture.minimumPressDuration = 0.5
        longPressGesture.delegate = context.coordinator
        pdfView.addGestureRecognizer(longPressGesture)
        
        // Add pan gesture for dragging markers
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        panGesture.delegate = context.coordinator
        pdfView.addGestureRecognizer(panGesture)
        
        // Don't set up failure requirements - let delegate handle it
        
        // Store reference
        context.coordinator.pdfView = pdfView
        
        // Create annotations for existing markers
        context.coordinator.syncMarkersToAnnotations()
        
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {
        // Update highlighting based on toggle
        if highlightingEnabled {
            if context.coordinator.highlighter?.highlightedAnnotations.isEmpty == true {
                context.coordinator.highlighter?.highlightAllTerms()
            }
        } else {
            context.coordinator.highlighter?.removeAllHighlights()
        }
        
        // Sync markers to annotations
        context.coordinator.syncMarkersToAnnotations()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: PDFKitView
        var highlighter: PDFTextHighlighter?
        var pdfView: PDFView?
        var draggedAnnotation: PDFAnnotation?
        var dragStartLocation: CGPoint?
        var isDragging = false
        
        init(_ parent: PDFKitView) {
            self.parent = parent
        }
        
        // Allow gestures to work together
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // Allow pan and PDFView's built-in gestures to coexist
            return true
        }
        
        // Decide whether gesture should begin
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pdfView = pdfView,
                  let page = pdfView.document?.page(at: 0) else { return true }
            
            let location = gestureRecognizer.location(in: pdfView)
            let locationOnPage = pdfView.convert(location, to: page)
            
            var isOverMarker = false
            for annotation in page.annotations {
                if (annotation is PDFCounterAnnotation || annotation is PDFNoteAnnotation),
                   annotation.bounds.contains(locationOnPage) {
                    isOverMarker = true
                    break
                }
            }
            
            // For pan gesture, only allow if we're over a marker
            if gestureRecognizer is UIPanGestureRecognizer {
                return isOverMarker
            }
            
            // For tap and long press, always allow
            return true
        }
        
        func syncMarkersToAnnotations() {
            guard let pdfView = pdfView,
                  let page = pdfView.document?.page(at: 0) else { return }
            
            // Remove all marker annotations
            let existingMarkers = page.annotations.compactMap { $0 as? PDFCounterAnnotation } + 
                                  page.annotations.compactMap { $0 as? PDFNoteAnnotation }
            existingMarkers.forEach { page.removeAnnotation($0) }
            
            // Add annotations for current markers
            let pageBounds = page.bounds(for: .mediaBox)
            
            for marker in parent.document.markers {
                // Convert normalized position (0-1) to PDF page coordinates
                let x = marker.positionX * pageBounds.width
                let y = marker.positionY * pageBounds.height
                
                if marker.type == .counter {
                    let annotationBounds = CGRect(x: x - 20, y: y - 20, width: 40, height: 40)
                    let annotation = PDFCounterAnnotation(
                        bounds: annotationBounds,
                        markerID: marker.id,
                        label: marker.counterLabel,
                        currentCount: marker.currentCount,
                        targetCount: marker.targetCount,
                        color: marker.color
                    )
                    page.addAnnotation(annotation)
                } else if marker.type == .note {
                    let annotationBounds = CGRect(x: x - 20, y: y - 20, width: 40, height: 40)
                    let annotation = PDFNoteAnnotation(
                        bounds: annotationBounds,
                        markerID: marker.id,
                        note: marker.note,
                        color: marker.color
                    )
                    page.addAnnotation(annotation)
                }
            }
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended,
                  let pdfView = pdfView else { return }
            
            let location = gesture.location(in: pdfView)
            guard let page = pdfView.page(for: location, nearest: true) else { return }
            
            let locationOnPage = pdfView.convert(location, to: page)
            
            // Check for counter annotations first
            for annotation in page.annotations {
                if let counterAnnotation = annotation as? PDFCounterAnnotation {
                    if counterAnnotation.bounds.contains(locationOnPage) {
                        // Show popup for counter
                        if let marker = parent.document.markers.first(where: { $0.id == counterAnnotation.markerID }) {
                            parent.selectedMarker = marker
                            parent.showingCounterPopup = true
                        }
                        return
                    }
                }
                
                // Check for note annotations
                if let noteAnnotation = annotation as? PDFNoteAnnotation,
                   noteAnnotation.bounds.contains(locationOnPage) {
                    // Show note popup
                    if let marker = parent.document.markers.first(where: { $0.id == noteAnnotation.markerID }) {
                        parent.selectedMarker = marker
                        parent.showingCounterPopup = true
                    }
                    return
                }
                
                // Check for terminology highlights
                if annotation.bounds.contains(locationOnPage),
                   let termAbbrev = annotation.userName,
                   let term = KnittingGlossary.term(for: termAbbrev) {
                    parent.selectedTerm = term
                    parent.showingTermDetail = true
                    return
                }
            }
        }
        
        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began,
                  let pdfView = pdfView else { return }
            
            let location = gesture.location(in: pdfView)
            guard let page = pdfView.page(for: location, nearest: true) else { return }
            
            let locationOnPage = pdfView.convert(location, to: page)
            
            // Check if long press is on an existing annotation
            for annotation in page.annotations {
                if (annotation is PDFCounterAnnotation || annotation is PDFNoteAnnotation),
                   annotation.bounds.contains(locationOnPage) {
                    // Long press on existing marker - show options menu
                    showMarkerOptionsMenu(for: annotation, at: location, in: pdfView)
                    return
                }
            }
        }
        
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let pdfView = pdfView else { return }
            
            let location = gesture.location(in: pdfView)
            guard let page = pdfView.page(for: location, nearest: true) else { return }
            
            let locationOnPage = pdfView.convert(location, to: page)
            
            switch gesture.state {
            case .began:
                // Find if we're touching a marker annotation
                for annotation in page.annotations {
                    if (annotation is PDFCounterAnnotation || annotation is PDFNoteAnnotation),
                       annotation.bounds.contains(locationOnPage) {
                        draggedAnnotation = annotation
                        dragStartLocation = locationOnPage
                        
                        // Don't set isDragging yet - wait for movement
                        break
                    }
                }
                
            case .changed:
                if let draggedAnnotation = draggedAnnotation,
                   let dragStartLocation = dragStartLocation {
                    
                    // Check if we've moved enough to start dragging
                    if !isDragging {
                        let translation = gesture.translation(in: pdfView)
                        let distance = sqrt(translation.x * translation.x + translation.y * translation.y)
                        
                        // Require 10 points of movement before starting drag
                        if distance > 10 {
                            isDragging = true
                            // Haptic feedback when drag actually starts
                            let impact = UIImpactFeedbackGenerator(style: .medium)
                            impact.impactOccurred()
                        } else {
                            // Not enough movement yet
                            return
                        }
                    }
                    
                    // Calculate offset
                    let dx = locationOnPage.x - dragStartLocation.x
                    let dy = locationOnPage.y - dragStartLocation.y
                    
                    // Move annotation
                    var newBounds = draggedAnnotation.bounds
                    newBounds.origin.x += dx
                    newBounds.origin.y += dy
                    draggedAnnotation.bounds = newBounds
                    
                    // Update drag start for next movement
                    self.dragStartLocation = locationOnPage
                    
                    // Force redraw
                    page.displaysAnnotations = true
                    pdfView.setNeedsDisplay()
                }
                
            case .ended, .cancelled:
                if let draggedAnnotation = draggedAnnotation, isDragging {
                    // Update the marker model with new position
                    let pageBounds = page.bounds(for: .mediaBox)
                    let center = CGPoint(
                        x: draggedAnnotation.bounds.midX,
                        y: draggedAnnotation.bounds.midY
                    )
                    
                    let normalizedX = center.x / pageBounds.width
                    let normalizedY = center.y / pageBounds.height
                    
                    // Find and update the corresponding marker
                    if let counterAnnotation = draggedAnnotation as? PDFCounterAnnotation,
                       let marker = parent.document.markers.first(where: { $0.id == counterAnnotation.markerID }) {
                        marker.positionX = normalizedX
                        marker.positionY = normalizedY
                        try? parent.document.modelContext?.save()
                    } else if let noteAnnotation = draggedAnnotation as? PDFNoteAnnotation,
                              let marker = parent.document.markers.first(where: { $0.id == noteAnnotation.markerID }) {
                        marker.positionX = normalizedX
                        marker.positionY = normalizedY
                        try? parent.document.modelContext?.save()
                    }
                    
                    // Haptic feedback
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                }
                
                draggedAnnotation = nil
                dragStartLocation = nil
                isDragging = false
                
            default:
                break
            }
        }
        
        private func showMarkerOptionsMenu(for annotation: PDFAnnotation, at location: CGPoint, in view: UIView) {
            var marker: Marker?
            
            if let counterAnnotation = annotation as? PDFCounterAnnotation {
                marker = parent.document.markers.first(where: { $0.id == counterAnnotation.markerID })
            } else if let noteAnnotation = annotation as? PDFNoteAnnotation {
                marker = parent.document.markers.first(where: { $0.id == noteAnnotation.markerID })
            }
            
            guard let marker = marker else { return }
            
            let alert = UIAlertController(title: "Marker Options", message: nil, preferredStyle: .actionSheet)
            
            alert.addAction(UIAlertAction(title: "Open", style: .default) { [weak self] _ in
                self?.parent.selectedMarker = marker
                self?.parent.showingCounterPopup = true
            })
            
            alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
                if let doc = marker.document {
                    doc.markers.removeAll { $0.id == marker.id }
                }
                self?.parent.document.modelContext?.delete(marker)
                self?.syncMarkersToAnnotations()
            })
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            
            // Present from view controller
            if let viewController = view.window?.rootViewController {
                if let popover = alert.popoverPresentationController {
                    popover.sourceView = view
                    popover.sourceRect = CGRect(origin: location, size: .zero)
                }
                viewController.present(alert, animated: true)
            }
        }
    }
}

// MARK: - Image Document View
struct ImageDocumentView: View {
    let imageData: Data
    @Bindable var document: InstructionDocument
    let highlightingEnabled: Bool
    @Environment(\.modelContext) private var modelContext
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.05) // Background to help see the bounds
                
                // Display the image with zoom and pan
                if let uiImage = UIImage(data: imageData) {
                    let imageSize = calculateImageSize(for: uiImage, in: geometry.size)
                    let imageFrame = CGRect(
                        x: (geometry.size.width - imageSize.width) / 2,
                        y: (geometry.size.height - imageSize.height) / 2,
                        width: imageSize.width,
                        height: imageSize.height
                    )
                    
                    ZStack {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: imageSize.width, height: imageSize.height)
                        
                        // Overlay for text highlighting using Vision framework
                        if highlightingEnabled {
                            ImprovedTextHighlightingOverlay(
                                image: uiImage,
                                imageFrame: imageFrame,
                                scale: scale,
                                offset: offset
                            )
                        }
                        
                        // Display existing markers ON TOP of the image
                        ForEach(document.markers) { marker in
                            ImprovedMarkerView(
                                marker: marker,
                                imageFrame: imageFrame,
                                scale: scale,
                                offset: offset
                            )
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        SimultaneousGesture(
                            MagnifyGesture()
                                .onChanged { value in
                                    let newScale = lastScale * value.magnification
                                    // Limit scale between 1x and 5x
                                    scale = min(max(newScale, 1.0), 5.0)
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                    // Reset position if zoomed back to 1x
                                    if scale == 1.0 {
                                        withAnimation(.spring(response: 0.3)) {
                                            offset = .zero
                                            lastOffset = .zero
                                        }
                                    }
                                },
                            DragGesture()
                                .onChanged { value in
                                    // Only allow panning if zoomed in
                                    guard scale > 1.0 else { return }
                                    
                                    let newOffset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                    
                                    // Calculate max offset based on scale
                                    let maxOffsetX = (geometry.size.width * (scale - 1)) / 2
                                    let maxOffsetY = (geometry.size.height * (scale - 1)) / 2
                                    
                                    // Constrain offset to prevent over-panning
                                    offset = CGSize(
                                        width: min(max(newOffset.width, -maxOffsetX), maxOffsetX),
                                        height: min(max(newOffset.height, -maxOffsetY), maxOffsetY)
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                    )
                }
            }
            .clipped() // Prevent content from spilling outside bounds
        }
    }
    
    /// Calculate the actual size of the image as displayed (aspect fit)
    private func calculateImageSize(for image: UIImage, in containerSize: CGSize) -> CGSize {
        let imageAspect = image.size.width / image.size.height
        let containerAspect = containerSize.width / containerSize.height
        
        if imageAspect > containerAspect {
            // Image is wider - fit to width
            let width = containerSize.width
            let height = width / imageAspect
            return CGSize(width: width, height: height)
        } else {
            // Image is taller - fit to height
            let height = containerSize.height
            let width = height * imageAspect
            return CGSize(width: width, height: height)
        }
    }
}



// MARK: - Marker View
struct MarkerView: View {
    @Bindable var marker: Marker
    let geometry: GeometryProxy
    @Environment(\.modelContext) private var modelContext
    
    @State private var isDragging = false
    @State private var showingEditor = false
    
    var body: some View {
        VStack {
            Text(displayIcon)
                .font(.title)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.9))
                        .shadow(radius: 3)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white, lineWidth: 2)
                )
        }
        .position(
            x: marker.positionX * geometry.size.width,
            y: marker.positionY * geometry.size.height
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDragging = true
                    marker.positionX = value.location.x / geometry.size.width
                    marker.positionY = value.location.y / geometry.size.height
                }
                .onEnded { _ in
                    isDragging = false
                }
        )
        .onTapGesture {
            showingEditor = true
        }
        .sheet(isPresented: $showingEditor) {
            MarkerNoteEditorView(marker: marker)
        }
    }
    
    var displayIcon: String {
        if marker.type == .counter {
            return "\(marker.currentCount)/\(marker.targetCount)"
        } else {
            return marker.note.isEmpty ? "📍" : "📝"
        }
    }
    
    var color: Color {
        switch marker.color {
        case "blue": return .blue
        case "green": return .green
        case "red": return .red
        case "yellow": return .yellow
        case "purple": return .purple
        default: return .blue
        }
    }
}

// MARK: - Improved Marker View (for zoomed images)
struct ImprovedMarkerView: View {
    @Bindable var marker: Marker
    let imageFrame: CGRect
    let scale: CGFloat
    let offset: CGSize
    @Environment(\.modelContext) private var modelContext
    
    @State private var isDragging = false
    @State private var showingEditor = false
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        VStack {
            Text(displayIcon)
                .font(.title)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.9))
                        .shadow(radius: 3)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white, lineWidth: 2)
                )
        }
        .position(
            x: marker.positionX * imageFrame.width,
            y: marker.positionY * imageFrame.height
        )
        .onTapGesture {
            showingEditor = true
        }
        .sheet(isPresented: $showingEditor) {
            MarkerNoteEditorView(marker: marker)
        }
    }
    
    var displayIcon: String {
        if marker.type == .counter {
            return "\(marker.currentCount)/\(marker.targetCount)"
        } else {
            return marker.note.isEmpty ? "📍" : "📝"
        }
    }
    
    var color: Color {
        switch marker.color {
        case "blue": return .blue
        case "green": return .green
        case "red": return .red
        case "yellow": return .yellow
        case "purple": return .purple
        default: return .blue
        }
    }
}

// MARK: - Marker Note Editor
struct MarkerNoteEditorView: View {
    @Bindable var marker: Marker
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // Get page count from document if available
    var maxPages: Int {
        guard let doc = marker.document,
              doc.isPDF,
              let pdfDoc = PDFDocument(data: doc.fileData) else {
            return 10 // Default fallback
        }
        return pdfDoc.pageCount
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Note") {
                    TextEditor(text: $marker.note)
                        .frame(minHeight: 100)
                }
                
                Section("Position") {
                    Picker("Page", selection: $marker.pageNumber) {
                        ForEach(0..<maxPages, id: \.self) { pageIndex in
                            Text("Page \(pageIndex + 1)").tag(pageIndex)
                        }
                    }
                }
                
                Section("Color") {
                    Picker("Marker Color", selection: $marker.color) {
                        HStack {
                            Circle().fill(.blue).frame(width: 16, height: 16)
                            Text("Blue")
                        }
                        .tag("blue")
                        
                        HStack {
                            Circle().fill(.green).frame(width: 16, height: 16)
                            Text("Green")
                        }
                        .tag("green")
                        
                        HStack {
                            Circle().fill(.red).frame(width: 16, height: 16)
                            Text("Red")
                        }
                        .tag("red")
                        
                        HStack {
                            Circle().fill(.orange).frame(width: 16, height: 16)
                            Text("Yellow")
                        }
                        .tag("yellow")
                        
                        HStack {
                            Circle().fill(.purple).frame(width: 16, height: 16)
                            Text("Purple")
                        }
                        .tag("purple")
                    }
                }
                
                Section {
                    Button("Delete Marker", role: .destructive) {
                        modelContext.delete(marker)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Counter color palette (shared by toolbar, row dots, edit sheet, and PDF badges)

let counterColorNames = [
    "sage", "mauve", "terracotta", "steel", "gold", "lavender",
    "forest", "rose", "slate", "amber", "plum", "linen"
]

func counterColor(for name: String) -> Color {
    switch name {
    case "sage":       return Color(red: 0.48, green: 0.68, blue: 0.56)
    case "mauve":      return Color(red: 0.75, green: 0.52, blue: 0.66)
    case "terracotta": return Color(red: 0.83, green: 0.45, blue: 0.35)
    case "steel":      return Color(red: 0.42, green: 0.61, blue: 0.75)
    case "gold":       return Color(red: 0.83, green: 0.66, blue: 0.26)
    case "lavender":   return Color(red: 0.61, green: 0.56, blue: 0.77)
    case "forest":     return Color(red: 0.42, green: 0.56, blue: 0.37)
    case "rose":       return Color(red: 0.91, green: 0.65, blue: 0.65)
    case "slate":      return Color(red: 0.48, green: 0.56, blue: 0.65)
    case "amber":      return Color(red: 0.79, green: 0.42, blue: 0.18)
    case "plum":       return Color(red: 0.48, green: 0.31, blue: 0.45)
    case "linen":      return Color(red: 0.78, green: 0.72, blue: 0.60)
    default:           return Color(red: 0.48, green: 0.68, blue: 0.56)
    }
}

/// Returns `.black` or `.white` — whichever gives higher WCAG contrast against the badge fill.
func counterTextColor(for name: String) -> Color {
    // Pre-computed from WCAG relative luminance — only plum (L≈0.13) needs white text.
    switch name {
    case "plum": return .white
    default:     return .black
    }
}

// MARK: - Document Toolbar Bar

struct DocumentToolbarTabs: View {
    @Binding var activeTab: ActiveTab?
    let isPDF: Bool

    var body: some View {
        HStack(spacing: 0) {
            if isPDF {
                ToolTabButton(
                    title: "Glossary",
                    icon: .magnifyingGlassCircle,
                    isActive: activeTab == .glossary
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        activeTab = activeTab == .glossary ? nil : .glossary
                    }
                }
            }

            ToolTabButton(
                title: "Counters",
                icon: .clock,
                isActive: activeTab == .counter
            ) {
                withAnimation(.spring(response: 0.3)) {
                    activeTab = activeTab == .counter ? nil : .counter
                }
            }

            ToolTabButton(
                title: "I'm Here",
                systemImage: "cursorarrow",
                isActive: activeTab == .marker
            ) {
                withAnimation(.spring(response: 0.3)) {
                    activeTab = activeTab == .marker ? nil : .marker
                }
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }
}

// MARK: - Marker Panel

struct MarkerPanelView: View {
    let hasMarker: Bool
    let onRefresh: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "cursorarrow")
                .font(.system(size: 18))
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("I'm Here Marker")
                    .font(.subheadline.weight(.medium))
                Text(hasMarker ? "Showing your last reading position" : "Tap refresh to mark your current position")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onRefresh) {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct ToolTabButton: View {
    let title: String
    let icon: AppIcon?
    let systemImage: String?
    let isActive: Bool
    let action: () -> Void

    init(title: String, icon: AppIcon, isActive: Bool, action: @escaping () -> Void) {
        self.title = title; self.icon = icon; self.systemImage = nil
        self.isActive = isActive; self.action = action
    }

    init(title: String, systemImage: String, isActive: Bool, action: @escaping () -> Void) {
        self.title = title; self.icon = nil; self.systemImage = systemImage
        self.isActive = isActive; self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                if let icon {
                    HeroIcon(icon, size: 22)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 22))
                }
                Text(title)
                    .font(.caption2)
            }
            .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
            .frame(width: 72, height: 48)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Glossary Panel

struct GlossaryPanelView: View {
    let lensTerms: [(term: KnittingGlossary.Term, screenRect: CGRect)]

    var body: some View {
        Group {
            if let closest = lensTerms.first {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(closest.term.abbreviation)
                                .font(.title3.bold())
                            Text(closest.term.fullName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Text(closest.term.definition)
                            .font(.body)
                            .foregroundStyle(.primary)
                        Text(closest.term.category.rawValue)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.accentColor.opacity(0.12)))
                            .foregroundStyle(Color.accentColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .frame(maxHeight: 160)
            } else {
                Text("Drag the lens over a knitting term")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            }
        }
    }
}

// MARK: - Counter Panel

struct CounterPanelView: View {
    let counters: [Marker]
    let onEdit: (Marker) -> Void
    let onDelete: (Marker) -> Void
    let onAddCounter: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("COUNTERS")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: onAddCounter) {
                    Label("Add Counter", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 6)

            // ScrollView + VStack avoids the List's swipe-to-delete gesture recognizer,
            // which competed with button taps and made the minus button feel unresponsive.
            ScrollView {
                VStack(spacing: 4) {
                    if counters.isEmpty {
                        Text("No counters in view")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 16)
                    } else {
                        ForEach(counters) { counter in
                            CounterRowView(counter: counter, onEdit: { onEdit(counter) })
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            .frame(maxHeight: 220)
        }
    }
}

// MARK: - Counter Row

struct CounterRowView: View {
    @Bindable var counter: Marker
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(counterColor(for: counter.color))
                .frame(width: 12, height: 12)

            Button {
                counter.decrement()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                HeroIcon(.minus, size: 14)
                    .frame(width: 36, height: 36)
                    .background(Circle().stroke(Color(.separator), lineWidth: 1))
                    // Extend the tap area beyond the visible circle so nearby taps register
                    .contentShape(Rectangle().size(CGSize(width: 52, height: 52))
                        .offset(x: -8, y: -8))
            }
            .buttonStyle(.borderless)
            .disabled(counter.currentCount == 0)

            Text("\(counter.currentCount)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .frame(minWidth: 36, alignment: .center)

            Button {
                counter.increment()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                HeroIcon(.plus, size: 14)
                    .frame(width: 36, height: 36)
                    .background(Circle().stroke(Color(.separator), lineWidth: 1))
                    .contentShape(Rectangle().size(CGSize(width: 52, height: 52))
                        .offset(x: -8, y: -8))
            }
            .buttonStyle(.borderless)
            .disabled(counter.targetCount > 0 && counter.currentCount >= counter.targetCount)

            if counter.targetCount > 0 {
                Text("/ \(counter.targetCount)")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onEdit) {
                HeroIcon(.pencil, size: 14)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Counter Edit Sheet

struct CounterEditSheet: View {
    @Bindable var counter: Marker
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var targetInput = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Color swatches — 6 columns × 2 rows
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6),
                          spacing: 14) {
                    ForEach(counterColorNames, id: \.self) { name in
                        Button {
                            counter.color = name
                        } label: {
                            Circle()
                                .fill(counterColor(for: name))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle()
                                        .strokeBorder(
                                            counter.color == name ? Color.primary : .clear,
                                            lineWidth: 3
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)

                Divider()

                // Set total
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.15))
                            .frame(width: 36, height: 36)
                        HeroIcon(.plus, size: 14)
                            .foregroundStyle(Color.accentColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Set total")
                            .font(.body)
                        Text("Current: \(counter.targetCount > 0 ? "\(counter.targetCount)" : "none")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    TextField("—", text: $targetInput)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .frame(width: 60, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.separator), lineWidth: 1)
                        )
                        .onChange(of: targetInput) { _, newValue in
                            if let val = Int(newValue), val > 0 {
                                counter.targetCount = val
                            } else if newValue.trimmingCharacters(in: .whitespaces).isEmpty {
                                counter.targetCount = 0
                            }
                        }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                Divider()

                // Remove counter
                Button {
                    // Dismiss first so the sheet animation completes before
                    // the PDF overlay rebuild fires (avoids visual jank).
                    let ctx = modelContext
                    let target = counter
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        ctx.delete(target)
                        try? ctx.save()
                    }
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.red.opacity(0.1))
                                .frame(width: 36, height: 36)
                            HeroIcon(.trash, size: 14)
                                .foregroundStyle(.red)
                        }
                        Text("Remove counter")
                            .foregroundStyle(.red)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)

                Divider()
                Spacer()
            }
            .navigationTitle(counter.counterLabel.isEmpty ? "Counter" : counter.counterLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                targetInput = counter.targetCount > 0 ? "\(counter.targetCount)" : ""
            }
        }
    }
}

// MARK: - Term Definition Card

struct TermDefinitionCard: View {
    let term: KnittingGlossary.Term

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(term.abbreviation)
                    .font(.title3.bold())
                Text(term.fullName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(term.definition)
                .font(.caption)
                .lineLimit(4)
                .foregroundStyle(.primary)
            Text(term.category.rawValue)
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                .foregroundStyle(Color.accentColor)
        }
        .padding(12)
        .frame(width: 200, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: InstructionDocument.self, Marker.self, KnittingProject.self,
        configurations: config
    )

    let sampleImage = UIImage(systemName: "photo")!
    let imageData = sampleImage.pngData()!
    let doc = InstructionDocument(
        title: "Sample Pattern",
        fileData: imageData,
        fileType: "image"
    )
    container.mainContext.insert(doc)

    let project = KnittingProject(name: "My Sweater", pattern: doc, status: .inProgress)
    container.mainContext.insert(project)

    return NavigationStack {
        DocumentViewerView(document: doc, project: project)
    }
    .modelContainer(container)
}
