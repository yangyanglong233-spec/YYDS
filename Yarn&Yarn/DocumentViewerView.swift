//
//  DocumentViewerView.swift
//  Yarn&Yarn
//
//  Created by Yangyang Long on 3/16/26.
//

import SwiftUI
import PDFKit
import SwiftData

struct DocumentViewerView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var document: InstructionDocument
    
    @State private var selectedTerminology: String?
    @State private var showingTerminologyPopover = false
    @State private var isDraggingMarker = false
    @State private var draggingMarkerType: Marker.MarkerType?
    @State private var newMarkerPosition: CGPoint?
    @State private var highlightingEnabled = true
    @State private var showingGlossary = false
    @State private var currentPage = 0 // Track current page
    @State private var showingTextReader = false // Toggle between PDF and text reader
    
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
                    // PDF viewer mode - with markers and highlighting
                    NativePDFDocumentView(pdfData: document.fileData, document: document, highlightingEnabled: highlightingEnabled, currentPage: $currentPage)
                }
            } else {
                ImageDocumentView(imageData: document.fileData, document: document, highlightingEnabled: highlightingEnabled)
            }
            
            // Marker palette (draggable source - top right, stays on screen)
            // Only show in PDF mode, not text reader mode
            if !showingTextReader {
                VStack {
                    HStack {
                        Spacer()
                        MarkerPaletteView(
                            isDragging: $isDraggingMarker,
                            onAddCounter: {
                                addCounter(at: CGPoint(x: 0.5, y: 0.5))
                            },
                            onAddNote: {
                                addNoteMarker(at: CGPoint(x: 0.5, y: 0.5))
                            }
                        )
                        .padding()
                        .zIndex(1000) // Ensure it stays on top
                    }
                    Spacer()
                }
            }
        }
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Text reader toggle (only for PDFs)
            if document.isPDF {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation {
                            showingTextReader.toggle()
                        }
                        
                        // Haptic feedback
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
            
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Menu {
                        Button {
                            addCounter(at: CGPoint(x: 0.5, y: 0.5))
                        } label: {
                            Label("Counter", systemImage: "number.circle")
                        }
                        
                        Button {
                            addNoteMarker(at: CGPoint(x: 0.5, y: 0.5))
                        } label: {
                            Label("Note", systemImage: "note.text")
                        }
                    } label: {
                        Label("Add Marker", systemImage: "plus.circle")
                    }
                    
                    Divider()
                    
                    Toggle(isOn: $highlightingEnabled) {
                        Label("Highlight Terms", systemImage: "highlighter")
                    }
                    
                    Button {
                        showingGlossary = true
                    } label: {
                        Label("View Glossary", systemImage: "book.closed")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingGlossary) {
            GlossaryBrowserView()
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
    
    private func addCounter(at position: CGPoint) {
        let newMarker = Marker.counterMarker(
            label: "Repeat",
            targetCount: 6,
            positionX: position.x,
            positionY: position.y,
            pageNumber: currentPage
        )
        newMarker.document = document
        document.markers.append(newMarker)
        modelContext.insert(newMarker)
        try? modelContext.save()
    }
}

// MARK: - Native PDF Document View
struct NativePDFDocumentView: View {
    let pdfData: Data
    @Bindable var document: InstructionDocument
    let highlightingEnabled: Bool
    @Binding var currentPage: Int

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
                    highlightingEnabled: highlightingEnabled,
                    currentPage: $currentPage
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
            .sheet(isPresented: $showingCounterPopup) {
                if let selectedMarker {
                    CounterPopupView(marker: selectedMarker)
                        .presentationDetents([.medium])
                }
            }
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
            if marker.type == .counter {
                CounterPopupView(marker: marker)
            } else {
                MarkerNoteEditorView(marker: marker)
            }
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
            if marker.type == .counter {
                CounterPopupView(marker: marker)
            } else {
                MarkerNoteEditorView(marker: marker)
            }
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

// MARK: - Marker Palette View
struct MarkerPaletteView: View {
    @Binding var isDragging: Bool
    
    var onAddCounter: () -> Void
    var onAddNote: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Add Markers")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            
            VStack(spacing: 12) {
                // Counter Marker Button
                Button(action: onAddCounter) {
                    MarkerPaletteCounterButton()
                }
                .buttonStyle(.plain)
                
                // Note Marker Button
                Button(action: onAddNote) {
                    MarkerPaletteNoteButton()
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        )
    }
}

struct MarkerPaletteCounterButton: View {
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.blue.gradient)
                    .frame(width: 50, height: 50)
                    .shadow(color: .blue.opacity(0.3), radius: 4, y: 2)
                
                VStack(spacing: 2) {
                    Image(systemName: "number.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                    
                    Text("0/6")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            
            Text("Counter")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }
}

struct MarkerPaletteNoteButton: View {
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.orange.gradient)
                    .frame(width: 50, height: 50)
                    .shadow(color: .orange.opacity(0.3), radius: 4, y: 2)
                
                Image(systemName: "note.text")
                    .font(.system(size: 22))
                    .foregroundStyle(.white)
            }
            
            Text("Note")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Counter Popup View
struct CounterPopupView: View {
    @Bindable var marker: Marker
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var showingEditor = false
    
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
            VStack(spacing: 24) {
                // Counter Display
                VStack(spacing: 8) {
                    Text(marker.counterLabel)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 4) {
                        Text("\(marker.currentCount)")
                            .font(.system(size: 60, weight: .bold, design: .rounded))
                            .foregroundStyle(marker.currentCount >= marker.targetCount ? .green : .primary)
                        
                        Text("/")
                            .font(.system(size: 40, weight: .medium))
                            .foregroundStyle(.secondary)
                        
                        Text("\(marker.targetCount)")
                            .font(.system(size: 40, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    
                    // Page indicator
                    Text("Page \(marker.pageNumber + 1)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    // Progress Bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.quaternary)
                            
                            RoundedRectangle(cornerRadius: 8)
                                .fill(marker.currentCount >= marker.targetCount ? Color.green : Color.blue)
                                .frame(width: geometry.size.width * min(CGFloat(marker.currentCount) / CGFloat(marker.targetCount), 1.0))
                        }
                    }
                    .frame(height: 12)
                    .padding(.horizontal)
                }
                
                // Buttons
                VStack(spacing: 16) {
                    // Increment/Decrement
                    HStack(spacing: 20) {
                        Button {
                            marker.decrement()
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(marker.currentCount > 0 ? .red : .gray.opacity(0.3))
                        }
                        .disabled(marker.currentCount == 0)
                        
                        Button {
                            marker.increment()
                            let impact = UIImpactFeedbackGenerator(style: .medium)
                            impact.impactOccurred()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(.green)
                        }
                    }
                    
                    // Quick Actions
                    HStack(spacing: 12) {
                        Button {
                            marker.reset()
                        } label: {
                            Label("Reset", systemImage: "arrow.counterclockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                        
                        Button {
                            showingEditor = true
                        } label: {
                            Label("Edit", systemImage: "pencil")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                        
                        Button(role: .destructive) {
                            modelContext.delete(marker)
                            dismiss()
                        } label: {
                            Label("Delete", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Counter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                CounterSettingsView(marker: marker)
            }
        }
    }
}

// MARK: - Counter Settings View
struct CounterSettingsView: View {
    @Bindable var marker: Marker
    @Environment(\.dismiss) private var dismiss
    
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
                Section("Counter Settings") {
                    TextField("Label", text: $marker.counterLabel)
                    
                    Stepper("Target: \(marker.targetCount)", value: $marker.targetCount, in: 1...999)
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
            }
            .navigationTitle("Edit Counter")
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

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: InstructionDocument.self,
        configurations: config
    )
    
    // Create sample document
    let sampleImage = UIImage(systemName: "photo")!
    let imageData = sampleImage.pngData()!
    let doc = InstructionDocument(
        title: "Sample Pattern",
        fileData: imageData,
        fileType: "image"
    )
    container.mainContext.insert(doc)
    
    return NavigationStack {
        DocumentViewerView(document: doc)
    }
    .modelContainer(container)
}
