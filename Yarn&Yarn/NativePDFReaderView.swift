//
//  NativePDFReaderView.swift
//  Yarn&Yarn
//
//  Created by Yangyang Long on 3/19/26.
//

import SwiftUI
import PDFKit
import SwiftData

/// A native SwiftUI-based PDF reader with full control over interactions
/// This uses PDFKit's PDFView for reliable zoom and scroll
struct NativePDFReaderView: View {
    let pdfDocument: PDFDocument
    @Bindable var document: InstructionDocument
    let highlightingEnabled: Bool
    @Binding var currentPage: Int
    
    @State private var selectedTerm: KnittingGlossary.Term?
    @State private var showingTermDetail = false
    @State private var isLoadingTerm = false
    @State private var selectedMarker: Marker?
    @State private var showingMarkerPopup = false
    @State private var pdfViewScale: CGFloat = 1.0
    
    // MARK: - Debug Text Extraction
    
    private func testTextExtraction(_ document: PDFDocument) {
        print("📄 Total pages: \(document.pageCount)")
        
        for i in 0..<min(document.pageCount, 3) {  // test first 3 pages only
            guard let page = document.page(at: i) else { continue }
            let raw = page.string ?? "NIL"
            
            print("--- PAGE \(i) ---")
            print("Character count: \(raw.count)")
            print("First 300 chars:")
            print(String(raw.prefix(300)))
            print("---")
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Page indicator
            if pdfDocument.pageCount > 1 {
                HStack {
                    Text("Page \(currentPage + 1) of \(pdfDocument.pageCount)")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
                .padding(.top, 8)
            }
            
            // PDFKit view
            NativePDFKitView(
                document: pdfDocument,
                instructionDocument: document,
                currentPage: $currentPage,
                scale: $pdfViewScale,
                highlightingEnabled: highlightingEnabled,
                selectedTerm: $selectedTerm,
                showingTermDetail: $showingTermDetail,
                isLoadingTerm: $isLoadingTerm,
                selectedMarker: $selectedMarker,
                showingMarkerPopup: $showingMarkerPopup
            )
            .id(pdfDocument) // Prevent recreation unless document changes
            .overlay(alignment: .center) {
                if isLoadingTerm {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .scaleEffect(1.5)
                    }
                }
            }
        }
        .onAppear {
            // Debug: Test text extraction quality
            testTextExtraction(pdfDocument)
        }
        .sheet(isPresented: $showingTermDetail, onDismiss: {
            selectedTerm = nil
        }) {
            if let selectedTerm {
                GlossaryTermDetailView(term: selectedTerm)
                    .presentationDetents([.medium, .large])
            }
        }
        .sheet(isPresented: $showingMarkerPopup) {
            if let selectedMarker {
                if selectedMarker.type == .counter {
                    CounterPopupView(marker: selectedMarker)
                        .presentationDetents([.medium])
                } else {
                    MarkerNoteEditorView(marker: selectedMarker)
                        .presentationDetents([.medium, .large])
                }
            }
        }
    }
}

// MARK: - PDFKit View Wrapper

struct NativePDFKitView: UIViewRepresentable {
    let document: PDFDocument
    let instructionDocument: InstructionDocument
    @Binding var currentPage: Int
    @Binding var scale: CGFloat
    let highlightingEnabled: Bool
    @Binding var selectedTerm: KnittingGlossary.Term?
    @Binding var showingTermDetail: Bool
    @Binding var isLoadingTerm: Bool
    @Binding var selectedMarker: Marker?
    @Binding var showingMarkerPopup: Bool
    
    @Environment(\.modelContext) private var modelContext
    
    func makeUIView(context: Context) -> UIView {
        // Create container view
        let containerView = UIView()
        containerView.backgroundColor = .systemBackground
        
        // Create PDFView
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .systemBackground
        pdfView.delegate = context.coordinator
        
        // Enable interaction with annotations
        pdfView.isUserInteractionEnabled = true
        
        // Add tap gesture to detect clicks on highlights (since PDFKit doesn't always trigger delegate for highlights)
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleTap(_:)))
        tapGesture.delegate = context.coordinator
        tapGesture.cancelsTouchesInView = false  // Don't prevent other gestures
        tapGesture.delaysTouchesBegan = false     // Respond immediately
        pdfView.addGestureRecognizer(tapGesture)
        
        // Add PDFView to container
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(pdfView)
        NSLayoutConstraint.activate([
            pdfView.topAnchor.constraint(equalTo: containerView.topAnchor),
            pdfView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            pdfView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        // Create transparent overlay view for markers (with touch passthrough)
        let overlayView = PassthroughView()
        overlayView.isUserInteractionEnabled = true
        overlayView.backgroundColor = UIColor.clear
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(overlayView)
        NSLayoutConstraint.activate([
            overlayView.topAnchor.constraint(equalTo: containerView.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        // Store references in coordinator
        context.coordinator.pdfView = pdfView
        context.coordinator.overlayView = overlayView
        context.coordinator.selectedTerm = $selectedTerm
        context.coordinator.showingTermDetail = $showingTermDetail
        context.coordinator.isLoadingTerm = $isLoadingTerm
        context.coordinator.selectedMarker = $selectedMarker
        context.coordinator.showingMarkerPopup = $showingMarkerPopup
        
        // Set initial page
        if let page = document.page(at: currentPage) {
            pdfView.go(to: page)
        }
        
        // Add highlights if enabled
        if highlightingEnabled {
            context.coordinator.addHighlights(page: currentPage)
        }
        
        // Setup continuous tracking with CADisplayLink
        context.coordinator.setupContinuousTracking()
        
        // Setup page change notification (still needed for highlights and page tracking)
        NotificationCenter.default.addObserver(
            forName: .PDFViewPageChanged,
            object: pdfView,
            queue: .main
        ) { _ in
            guard let currentPDFPage = pdfView.currentPage else { return }
            let index = document.index(for: currentPDFPage)
            context.coordinator.updateCurrentPage(index)
            
            // Update highlights for new page
            if context.coordinator.highlightingEnabled {
                context.coordinator.addHighlights(page: index)
            }
            
            // Update markers for all pages (vertical scroll shows markers across pages)
            context.coordinator.rebuildMarkerViews(markers: context.coordinator.instructionDocument.markers)
        }
        
        // Initial marker layout — show all pages' markers at once
        context.coordinator.rebuildMarkerViews(markers: instructionDocument.markers)
        
        return containerView
    }
    
    func updateUIView(_ containerView: UIView, context: Context) {
        print("DEBUG: updateUIView called")
        
        guard let pdfView = context.coordinator.pdfView else {
            print("DEBUG: No pdfView in coordinator")
            return
        }
        
        // Check if any marker is currently being dragged
        let anyDragging = context.coordinator.markerViewMap.values.contains { $0.isDragging }
        guard !anyDragging else {
            print("🟡 Skipping rebuild — marker is being dragged")
            return
        }
        
        // Update bindings in case they changed
        context.coordinator.selectedTerm = $selectedTerm
        context.coordinator.showingTermDetail = $showingTermDetail
        context.coordinator.isLoadingTerm = $isLoadingTerm
        context.coordinator.selectedMarker = $selectedMarker
        context.coordinator.showingMarkerPopup = $showingMarkerPopup
        
        let oldHighlightingEnabled = context.coordinator.highlightingEnabled
        context.coordinator.highlightingEnabled = highlightingEnabled
        context.coordinator.instructionDocument = instructionDocument
        
        // Update to new page if changed externally
        guard let currentPDFPage = pdfView.currentPage else {
            print("DEBUG: updateUIView - no current page yet, scheduling for later")
            // Page not loaded yet, try again after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let page = pdfView.currentPage {
                    let index = self.document.index(for: page)
                    if self.highlightingEnabled {
                        context.coordinator.addHighlights(page: index)
                    }
                    context.coordinator.rebuildMarkerViews(markers: self.instructionDocument.markers)
                }
            }
            return
        }
        
        let currentIndex = document.index(for: currentPDFPage)
        
        if currentIndex != currentPage,
           let newPage = document.page(at: currentPage) {
            pdfView.go(to: newPage)
        }
        
        // Only update highlights if the highlighting state changed
        if highlightingEnabled != oldHighlightingEnabled {
            if highlightingEnabled {
                context.coordinator.addHighlights(page: currentPage)
            } else {
                context.coordinator.removeHighlights()
            }
        }
        
        // Check if any markers across all pages have changed
        let allMarkers = instructionDocument.markers
        let incomingIDs = Set(allMarkers.map { $0.id })
        // Combine both marker views and highlight layers for accurate change detection
        let existingIDs = Set(context.coordinator.markerViewMap.keys).union(Set(context.coordinator.highlightLayerMap.keys))

        let shouldRebuild = incomingIDs != existingIDs
        print("🟡 updateUIView called - will rebuild: \(shouldRebuild)")

        if shouldRebuild {
            // Markers were added or removed — full rebuild needed
            context.coordinator.rebuildMarkerViews(markers: allMarkers)
        } else {
            // Same markers, just reposition (zoom/scroll/SwiftUI redraw)
            context.coordinator.repositionMarkerViews()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            currentPage: $currentPage,
            scale: $scale,
            document: document,
            instructionDocument: instructionDocument,
            modelContext: modelContext
        )
    }
    
    class Coordinator: NSObject, PDFViewDelegate, UIGestureRecognizerDelegate {
        @Binding var currentPage: Int
        @Binding var scale: CGFloat
        var selectedTerm: Binding<KnittingGlossary.Term?>?
        var showingTermDetail: Binding<Bool>?
        var isLoadingTerm: Binding<Bool>?
        var selectedMarker: Binding<Marker?>?
        var showingMarkerPopup: Binding<Bool>?
        weak var pdfView: PDFView?
        weak var overlayView: UIView?
        let document: PDFDocument
        var instructionDocument: InstructionDocument
        var highlightingEnabled = false
        let modelContext: ModelContext
        private var currentHighlightAnnotations: [TermHighlightAnnotation] = []
        private weak var selectedHighlightAnnotation: TermHighlightAnnotation?
        
        // Marker views keyed by marker ID for efficient repositioning
        var markerViewMap: [UUID: SimpleMarkerView] = [:]
        private var currentMarkers: [Marker] = []
        
        // Highlight shape layers keyed by marker ID
        var highlightLayerMap: [UUID: CAShapeLayer] = [:]
        
        // CADisplayLink for continuous tracking
        private var displayLink: CADisplayLink?
        
        // Track which marker is currently being dragged
        var draggingMarkerID: UUID?
        var draggingMarkerView: SimpleMarkerView?
        
        // Keep a strong reference to the haptic generator
        private let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
        
        init(currentPage: Binding<Int>, scale: Binding<CGFloat>, document: PDFDocument, instructionDocument: InstructionDocument, modelContext: ModelContext) {
            _currentPage = currentPage
            _scale = scale
            self.document = document
            self.instructionDocument = instructionDocument
            self.modelContext = modelContext
            super.init()
            
            // Prepare the haptic generator once at initialization
            impactGenerator.prepare()
        }
        
        deinit {
            // Invalidate display link
            displayLink?.invalidate()
        }
        
        func updateCurrentPage(_ page: Int) {
            currentPage = page
        }
        
        func updateScale(_ newScale: CGFloat) {
            scale = newScale
        }
        
        // MARK: - Continuous Tracking
        
        func setupContinuousTracking() {
            // CADisplayLink — runs every frame, no stopping
            let link = CADisplayLink(target: self, selector: #selector(repositionMarkerViews))
            link.add(to: .main, forMode: .common)
            self.displayLink = link
        }
        
        // MARK: - Marker Management
        
        /// Rebuild marker views when markers array changes (add/remove/load)
        func rebuildMarkerViews(markers: [Marker]) {
            print("🔴 rebuildMarkerViews called")
            guard let overlayView = overlayView,
                  let pdfView = pdfView else {
                print("DEBUG: Cannot rebuild markers - overlayView or pdfView is nil")
                return
            }
            
            print("DEBUG: rebuildMarkerViews called with \(markers.count) markers")
            
            // Remove all existing marker views
            for (_, markerView) in markerViewMap {
                markerView.removeFromSuperview()
            }
            markerViewMap.removeAll()
            
            // Remove all existing highlight layers
            for (_, layer) in highlightLayerMap {
                layer.removeFromSuperlayer()
            }
            highlightLayerMap.removeAll()
            
            // Store current markers
            currentMarkers = markers
            
            // Find presenting view controller for alerts
            var presentingVC: UIViewController?
            if let window = overlayView.window {
                presentingVC = window.rootViewController
                // Traverse to find topmost presented controller
                while let presented = presentingVC?.presentedViewController {
                    presentingVC = presented
                }
            }
            
            // Create new marker views
            for marker in markers {
                // Skip highlight markers - they use CAShapeLayer, not UIView
                if marker.type == .highlight {
                    continue
                }
                
                let markerView = SimpleMarkerView(marker: marker, target: marker.targetCount)
                markerView.presentingViewController = presentingVC
                
                // Set callback to set dragging state
                markerView.onSetDragging = { [weak self, weak markerView] in
                    self?.draggingMarkerView = markerView
                    self?.draggingMarkerID = marker.id
                }
                
                // Set callback to save context when count changes
                markerView.onCountChanged = { [weak self] _ in
                    try? self?.modelContext.save()
                }
                
                // Set callback when drag starts
                markerView.onDragStarted = { [weak self] in
                    self?.draggingMarkerID = marker.id
                    self?.draggingMarkerView = markerView
                }
                
                // Set callback when drag ends
                markerView.onDragEnded = { [weak self] finalCenter in
                    guard let self = self,
                          let pdfView = self.pdfView,
                          let overlayView = self.overlayView else { return }
                    
                    // Convert overlay center → PDFView coordinate space
                    let pdfPoint = pdfView.convert(finalCenter, from: overlayView)
                    
                    // Find which page the drop landed on
                    guard let page = pdfView.page(for: pdfPoint, nearest: true),
                          let pageIndex = pdfView.document?.index(for: page) else { return }
                    
                    // Convert to PDF page coordinate space — this is what survives zoom
                    let pagePoint = pdfView.convert(pdfPoint, to: page)
                    
                    // Persist — store normalized 0–1 relative to page bounds
                    let pageBounds = page.bounds(for: .mediaBox)
                    marker.positionX = pagePoint.x / pageBounds.width
                    marker.positionY = pagePoint.y / pageBounds.height
                    marker.pageNumber = pageIndex
                    
                    try? self.modelContext.save()
                    
                    // Clear dragging state only after position is fully persisted
                    self.draggingMarkerID = nil
                    self.draggingMarkerView = nil
                    
                    // Rebuild all markers so moved marker appears on its new page
                    self.rebuildMarkerViews(markers: self.instructionDocument.markers)
                    self.repositionMarkerViews()
                }
                
                // Set callback to update position when marker is moved (legacy - can be removed)
                markerView.onMoved = { [weak self] newOverlayCenter in
                    guard let self = self,
                          let pdfView = self.pdfView,
                          let overlayView = self.overlayView else { return }
                    
                    // Convert overlay center → PDFView coordinate space
                    let pdfPoint = pdfView.convert(newOverlayCenter, from: overlayView)
                    
                    // Find which page the drop landed on
                    guard let page = pdfView.page(for: pdfPoint, nearest: true),
                          let pageIndex = pdfView.document?.index(for: page) else { return }
                    
                    // Convert to PDF page coordinate space — this is what survives zoom
                    let pagePoint = pdfView.convert(pdfPoint, to: page)
                    
                    // Persist — store normalized 0–1 relative to page bounds
                    let pageBounds = page.bounds(for: .mediaBox)
                    marker.positionX = pagePoint.x / pageBounds.width
                    marker.positionY = pagePoint.y / pageBounds.height
                    marker.pageNumber = pageIndex
                    
                    try? self.modelContext.save()
                    
                    // Rebuild all markers so moved marker appears on its new page
                    self.rebuildMarkerViews(markers: self.instructionDocument.markers)
                    self.repositionMarkerViews()
                }
                
                // Set callback to remove marker
                markerView.onRemove = { [weak self] in
                    guard let self = self else { return }
                    self.modelContext.delete(marker)
                    try? self.modelContext.save()
                    
                    // Rebuild all markers after removal
                    self.rebuildMarkerViews(markers: self.instructionDocument.markers)
                    self.repositionMarkerViews()
                }
                
                // Add to overlay
                overlayView.addSubview(markerView)
                
                // Store in map
                markerViewMap[marker.id] = markerView
            }
            
            // Create highlight layers
            for marker in markers {
                // Only process highlight markers
                guard marker.type == .highlight,
                      let pageRect = marker.pageRect,
                      let page = pdfView.document?.page(at: marker.pageNumber) else {
                    continue
                }
                
                // Convert normalized pageRect (0-1) to PDF page coordinates
                let pageBounds = page.bounds(for: .mediaBox)
                let pdfRect = CGRect(
                    x: pageRect.origin.x * pageBounds.width,
                    y: pageRect.origin.y * pageBounds.height,
                    width: pageRect.width * pageBounds.width,
                    height: pageRect.height * pageBounds.height
                )
                
                // Convert PDF rect to screen coordinates
                let rectInPDFView = pdfView.convert(pdfRect, from: page)
                
                // Convert from PDFView space to overlay space
                guard let containerView = overlayView.superview else { continue }
                let rectInContainer = pdfView.convert(rectInPDFView, to: containerView)
                let rectInOverlay = overlayView.convert(rectInContainer, from: containerView)
                
                // Determine style and generate path
                let highlightStyle = marker.highlightStyle ?? .yarnLoop  // Default to yarnLoop if nil
                
                // Compute scale factor from rendered text height
                let referenceLineHeight: CGFloat = 14.0
                let scale = rectInOverlay.height / referenceLineHeight
                
                let path: UIBezierPath
                switch highlightStyle {
                case .yarnLoop:
                    path = HighlightPathRenderer.yarnLoopPath(width: rectInOverlay.width, scale: scale)
                case .scallop:
                    path = HighlightPathRenderer.scallopPath(width: rectInOverlay.width, scale: scale)
                }
                
                // Translate path to position
                let gap: CGFloat = 1 * scale  // Adjusted: closer to text (less overlap)
                let translation = CGAffineTransform(translationX: rectInOverlay.minX, y: rectInOverlay.maxY + gap)
                path.apply(translation)
                
                // Create shape layer
                let shapeLayer = CAShapeLayer()
                shapeLayer.path = path.cgPath
                shapeLayer.fillColor = UIColor.clear.cgColor
                shapeLayer.lineWidth = min(max(2.0 / scale, 0.5), 4.0)
                
                // Set stroke color based on style
                switch highlightStyle {
                case .yarnLoop:
                    shapeLayer.strokeColor = UIColor(red: 0xFF/255.0, green: 0x8C/255.0, blue: 0x3E/255.0, alpha: 0.64).cgColor
                case .scallop:
                    shapeLayer.strokeColor = UIColor(red: 0xC0/255.0, green: 0x40/255.0, blue: 0x20/255.0, alpha: 0.7).cgColor
                }
                
                // Add to overlay
                overlayView.layer.addSublayer(shapeLayer)
                
                // Store in map
                highlightLayerMap[marker.id] = shapeLayer
            }
            
            // Initial positioning
            repositionMarkerViews()
        }
        
        /// Reposition existing marker views (called continuously during zoom/scroll)
        @objc func repositionMarkerViews() {
            guard let pdfView = pdfView,
                  let overlayView = overlayView else { return }
            
            // Temporary log to verify continuous tracking
            //print("⏱ tick — scale: \(pdfView.scaleFactor), markerCount: \(markerViewMap.count)")
            
            let scale = pdfView.scaleFactor
            
            // Update scale binding
            updateScale(scale)
            
            for (id, markerView) in markerViewMap {
                // Store current zoom scale before checking drag state
                markerView.currentZoomScale = scale
                
                // Skip the marker that's currently being dragged
                if markerView.isDragging {
                    print("🟢 Skipping dragging marker - isDragging: \(markerView.isDragging)")
                    continue
                }
                
                guard let marker = currentMarkers.first(where: { $0.id == id }),
                      let page = pdfView.document?.page(at: marker.pageNumber) else {
                    print("❌ marker \(id) — page lookup failed")
                    continue
                }
                
                // Convert normalized position (0-1) to PDF page coordinates
                let pageBounds = page.bounds(for: .mediaBox)
                let pdfX = marker.positionX * pageBounds.width
                let pdfY = marker.positionY * pageBounds.height
                let pointInPage = CGPoint(x: pdfX, y: pdfY)
                
                // Convert PDF page coordinates to screen coordinates (in PDFView space)
                let pointInPDFView = pdfView.convert(pointInPage, from: page)
                
                // Convert from PDFView space to overlay space
                guard let containerView = overlayView.superview else {
                    print("❌ marker \(id) — convert from page failed")
                    continue
                }
                let pointInContainer = pdfView.convert(pointInPDFView, to: containerView)
                let pointInOverlay = overlayView.convert(pointInContainer, from: containerView)
                
                // Update position and scale (order is critical!)
                markerView.transform = .identity  // 1. Reset transform first
                markerView.center = pointInOverlay  // 2. Set center on identity
                markerView.transform = CGAffineTransform(scaleX: scale, y: scale)  // 3. Then apply scale
            }
            
            // Reposition highlight layers
            for (id, shapeLayer) in highlightLayerMap {
                guard let marker = currentMarkers.first(where: { $0.id == id }),
                      marker.type == .highlight,
                      let pageRect = marker.pageRect,
                      let page = pdfView.document?.page(at: marker.pageNumber) else {
                    continue
                }
                
                // Convert normalized pageRect (0-1) to PDF page coordinates
                let pageBounds = page.bounds(for: .mediaBox)
                let pdfRect = CGRect(
                    x: pageRect.origin.x * pageBounds.width,
                    y: pageRect.origin.y * pageBounds.height,
                    width: pageRect.width * pageBounds.width,
                    height: pageRect.height * pageBounds.height
                )
                
                // Convert PDF rect to screen coordinates
                let rectInPDFView = pdfView.convert(pdfRect, from: page)
                
                // Convert from PDFView space to overlay space
                guard let containerView = overlayView.superview else { continue }
                let rectInContainer = pdfView.convert(rectInPDFView, to: containerView)
                let rectInOverlay = overlayView.convert(rectInContainer, from: containerView)
                
                // Determine style and regenerate path with new width
                let highlightStyle = marker.highlightStyle ?? .yarnLoop  // Default to yarnLoop if nil
                
                // Compute scale factor from rendered text height
                let referenceLineHeight: CGFloat = 14.0
                let scale = rectInOverlay.height / referenceLineHeight
                
                let path: UIBezierPath
                switch highlightStyle {
                case .yarnLoop:
                    path = HighlightPathRenderer.yarnLoopPath(width: rectInOverlay.width, scale: scale)
                case .scallop:
                    path = HighlightPathRenderer.scallopPath(width: rectInOverlay.width, scale: scale)
                }
                
                // Translate path to position
                let gap: CGFloat = 1 * scale  // Adjusted: closer to text (less overlap)
                let translation = CGAffineTransform(translationX: rectInOverlay.minX, y: rectInOverlay.maxY + gap)
                path.apply(translation)
                
                // Update layer path
                shapeLayer.path = path.cgPath
            }
        }
        
        // MARK: - Gesture Handling
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            // Only handle taps that have ended (not began, changed, cancelled)
            guard gesture.state == .ended else {
                print("DEBUG: Ignoring gesture in state: \(gesture.state.rawValue)")
                return
            }
            
            print("DEBUG: handleTap called - gesture state: \(gesture.state.rawValue)")
            
            guard let pdfView = pdfView else {
                print("DEBUG: No pdfView")
                return
            }

            let locationInView = gesture.location(in: pdfView)
            guard let page = pdfView.page(for: locationInView, nearest: false) else {
                print("DEBUG: Tap not on any page")
                return
            }
            let locationInPage = pdfView.convert(locationInView, to: page)
            
            print("DEBUG: Tap at page coordinates: \(locationInPage)")
            print("DEBUG: Current highlights count: \(currentHighlightAnnotations.count)")
            
            // Check highlights
            for annotation in currentHighlightAnnotations {
                if annotation.bounds.contains(locationInPage) {
                    print("DEBUG: Tap on highlight detected - Term: \(annotation.term.abbreviation)")
                    
                    // Trigger haptic feedback immediately
                    impactGenerator.impactOccurred()
                    // Prepare for next tap
                    impactGenerator.prepare()
                    
                    // Deselect previous annotation
                    selectedHighlightAnnotation?.setSelected(false)
                    
                    // Select this annotation with press effect
                    annotation.setSelected(true)
                    selectedHighlightAnnotation = annotation
                    
                    // Show loading indicator
                    isLoadingTerm?.wrappedValue = true
                    
                    // Set the term
                    selectedTerm?.wrappedValue = annotation.term
                    
                    // Wait for state to propagate, then show sheet and hide loader
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        self.isLoadingTerm?.wrappedValue = false
                        self.showingTermDetail?.wrappedValue = true
                    }
                    
                    // Deselect after a delay (visual feedback fades)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        annotation.setSelected(false)
                        if self.selectedHighlightAnnotation === annotation {
                            self.selectedHighlightAnnotation = nil
                        }
                    }
                    
                    return
                }
            }
            
            print("DEBUG: Tap on empty area")
        }
        
        // MARK: - UIGestureRecognizerDelegate
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // Allow our tap gesture to work alongside PDFView's gestures
            return true
        }
        
        // MARK: - PDFViewDelegate
        
        func pdfViewWillClick(onLink sender: PDFView, with url: URL) {
            // Not handling links
        }
        
        func pdfViewPerformGo(toPage sender: PDFView, with destination: PDFDestination) {
            // Allow default behavior
        }
        
        // This is called when user clicks on an annotation
        func pdfView(_ pdfView: PDFView, didClick annotation: PDFAnnotation) {
            print("DEBUG: Annotation clicked - Type: \(type(of: annotation))")
            
            // Only handle term highlights (markers are now in overlay)
            if let termAnnotation = annotation as? TermHighlightAnnotation {
                print("DEBUG: Term annotation tapped - Term: \(termAnnotation.term.abbreviation)")
                
                // Trigger haptic feedback
                impactGenerator.impactOccurred()
                impactGenerator.prepare()
                
                selectedTerm?.wrappedValue = termAnnotation.term
                showingTermDetail?.wrappedValue = true
                return
            }
            
            print("DEBUG: Unknown annotation type")
        }
        
        // MARK: - Highlights
        
        func addHighlights(page pageIndex: Int) {
            guard let page = document.page(at: pageIndex),
                  let pageText = page.string else {
                print("DEBUG: Cannot add highlights - no page or text")
                return
            }
            
            print("DEBUG: Adding highlights for page \(pageIndex)")
            
            // First, remove ALL existing highlight annotations from this specific page
            let existingAnnotations = page.annotations
            for annotation in existingAnnotations {
                if annotation is TermHighlightAnnotation {
                    page.removeAnnotation(annotation)
                }
            }
            
            // Remove existing highlight markers for this page
            let existingHighlightMarkers = instructionDocument.markers.filter {
                $0.type == .highlight && $0.pageNumber == pageIndex
            }
            for marker in existingHighlightMarkers {
                modelContext.delete(marker)
            }
            
            // Clear our tracking array
            currentHighlightAnnotations.removeAll()
            
            // Now add new highlights
            let foundTerms = KnittingGlossary.findTerms(in: pageText)
            print("DEBUG: Found \(foundTerms.count) terms to highlight")
            
            // Get page bounds for normalization
            let pageBounds = page.bounds(for: .mediaBox)
            
            for (term, range) in foundTerms {
                let nsRange = NSRange(range, in: pageText)
                
                if let selection = page.selection(for: nsRange) {
                    let bounds = selection.bounds(for: page)
                    
                    // Create a clickable highlight annotation (for glossary tap interaction)
                    let highlightAnnotation = TermHighlightAnnotation(bounds: bounds, term: term)
                    highlightAnnotation.setBaseColor(UIColor(red: 1.0, green: 0.9, blue: 0.4, alpha: 0.6))
                    // Make sure the annotation is interactive
                    highlightAnnotation.isReadOnly = false
                    
                    page.addAnnotation(highlightAnnotation)
                    currentHighlightAnnotations.append(highlightAnnotation)
                    
                    print("DEBUG: Added highlight for '\(term.abbreviation)' at bounds: \(bounds)")
                    
                    // Create a Marker object for decorative underline rendering
                    // Normalize bounds to 0-1 coordinate space
                    let normalizedRect = CGRect(
                        x: bounds.origin.x / pageBounds.width,
                        y: bounds.origin.y / pageBounds.height,
                        width: bounds.width / pageBounds.width,
                        height: bounds.height / pageBounds.height
                    )
                    
                    let highlightMarker = Marker(
                        type: .highlight,
                        positionX: normalizedRect.origin.x,
                        positionY: normalizedRect.origin.y,
                        pageNumber: pageIndex,
                        color: "purple"  // Use purple for yarnLoop style
                    )
                    highlightMarker.rectX = normalizedRect.origin.x
                    highlightMarker.rectY = normalizedRect.origin.y
                    highlightMarker.rectWidth = normalizedRect.width
                    highlightMarker.rectHeight = normalizedRect.height
                    highlightMarker.highlightStyle = .yarnLoop
                    highlightMarker.document = instructionDocument
                    
                    // Insert into SwiftData
                    modelContext.insert(highlightMarker)
                }
            }
            
            // Save all new markers
            try? modelContext.save()
            
            print("DEBUG: Total highlights added: \(currentHighlightAnnotations.count)")
            
            // Rebuild all marker views to render the new highlight layers immediately
            rebuildMarkerViews(markers: instructionDocument.markers)
            
            // Show all highlight layers when highlights are enabled
            for (_, layer) in highlightLayerMap {
                layer.isHidden = false
            }
        }
        
        func removeHighlights() {
            // Hide all highlight layers when highlights are disabled
            for (_, layer) in highlightLayerMap {
                layer.isHidden = true
            }
            
            // Remove all highlight annotations from all pages
            for pageIndex in 0..<document.pageCount {
                if let page = document.page(at: pageIndex) {
                    let existingAnnotations = page.annotations
                    for annotation in existingAnnotations {
                        if annotation is TermHighlightAnnotation {
                            page.removeAnnotation(annotation)
                        }
                    }
                }
            }
            
            // Remove all highlight markers from all pages
            let allHighlightMarkers = instructionDocument.markers.filter { $0.type == .highlight }
            for marker in allHighlightMarkers {
                modelContext.delete(marker)
            }
            try? modelContext.save()
            
            currentHighlightAnnotations.removeAll()
            
            // Rebuild all markers to remove highlight layers
            rebuildMarkerViews(markers: instructionDocument.markers)
        }
        
        private func highlightColor(for category: KnittingGlossary.Category) -> UIColor {
            switch category {
            case .basicStitches:
                return .systemYellow
            case .increases, .decreases:
                return .systemOrange
            case .castOn, .bindOff:
                return .systemGreen
            case .cables:
                return .systemPurple
            case .colorwork:
                return .systemPink
            case .lace:
                return .systemCyan
            default:
                return .systemBlue
            }
        }
    }
}

// MARK: - Term Highlight Annotation

class TermHighlightAnnotation: PDFAnnotation {
    let term: KnittingGlossary.Term
    private var isSelected: Bool = false
    private var baseColor: UIColor = .clear
    
    init(bounds: CGRect, term: KnittingGlossary.Term) {
        self.term = term
        super.init(bounds: bounds, forType: .highlight, withProperties: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setSelected(_ selected: Bool, animated: Bool = true) {
        guard isSelected != selected else { return }
        isSelected = selected
        
        if animated {
            // Animate the color change
            UIView.animate(withDuration: 0.15, delay: 0, options: [.curveEaseOut]) {
                self.updateAppearance()
            }
        } else {
            updateAppearance()
        }
    }
    
    private func updateAppearance() {
        if isSelected {
            // Pressed state - darker and more opaque
            self.color = baseColor.withAlphaComponent(0.7)
        } else {
            // Normal state
            self.color = baseColor.withAlphaComponent(0.3)
        }
    }
    
    func setBaseColor(_ color: UIColor) {
        self.baseColor = color
        self.color = color.withAlphaComponent(0.3)
    }
    
    override func draw(with box: PDFDisplayBox, in context: CGContext) {
        // Custom drawing for rounded rectangle highlight with enhanced visual polish
        context.saveGState()
        
        // More prominent corner radius for better visual appeal
        let cornerRadius: CGFloat = 6
        let insetBounds = self.bounds.insetBy(dx: 0.5, dy: 0.5)
        
        // Create rounded rectangle path
        let path = UIBezierPath(roundedRect: insetBounds, cornerRadius: cornerRadius)
        
        // Fill with highlight color
        let fillColor = self.color ?? baseColor.withAlphaComponent(0.3)
        context.setFillColor(fillColor.cgColor)
        context.addPath(path.cgPath)
        context.fillPath()
        
        // Add border when pressed
        if isSelected {
            let borderColor = baseColor.withAlphaComponent(1.0)
            context.setStrokeColor(borderColor.cgColor)
            context.setLineWidth(2.5) // Slightly thicker for better visibility
            
            // Recreate path for stroke (since we already filled)
            let strokePath = UIBezierPath(roundedRect: insetBounds, cornerRadius: cornerRadius)
            context.addPath(strokePath.cgPath)
            context.strokePath()
            
            // Add subtle shadow for depth when selected
            context.setShadow(
                offset: CGSize(width: 0, height: 2),
                blur: 4,
                color: borderColor.withAlphaComponent(0.5).cgColor
            )
        }
        
        context.restoreGState()
    }
}

// MARK: - Passthrough View for Touch Handling

/// A UIView subclass that only captures touches on its subviews, passing through all other touches
class PassthroughView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit == self ? nil : hit
    }
}

// MARK: - Simple Marker View

/// A UIKit-based marker view that doesn't use SwiftUI or UIHostingController
class SimpleMarkerView: UIView {
    let marker: Marker
    let target: Int
    weak var presentingViewController: UIViewController?
    
    var isDragging: Bool = false
    var currentZoomScale: CGFloat = 1.0
    
    var onCountChanged: ((Int) -> Void)?
    var onMoved: ((CGPoint) -> Void)?
    var onRemove: (() -> Void)?
    var onSetDragging: (() -> Void)?
    var onDragStarted: (() -> Void)?
    var onDragEnded: ((CGPoint) -> Void)?
    
    private let innerView = UIView()
    private let countLabel = UILabel()
    private var checkmarkImageView: UIImageView?
    private var tapGesture: UITapGestureRecognizer?
    private var svgShapeLayer: CAShapeLayer?  // SVG background for counter markers
    
    init(marker: Marker, target: Int) {
        self.marker = marker
        self.target = target
        super.init(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        setupView()
        setupGestures()
        updateAppearance()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        // Configure outer view
        backgroundColor = .clear
        clipsToBounds = false
        isUserInteractionEnabled = true
        
        // Try to load SVG background for counter markers
        if marker.type == .counter {
            setupSVGBackground()
        }
        
        // Configure inner view (36x36, centered in 44x44 frame)
        innerView.frame = CGRect(x: 4, y: 4, width: 36, height: 36)
        
        // Only set background if SVG didn't load
        if svgShapeLayer == nil {
            innerView.backgroundColor = .systemYellow  // Default background
            innerView.layer.cornerRadius = 10
        } else {
            innerView.backgroundColor = .clear
            innerView.layer.cornerRadius = 0
        }
        
        innerView.layer.shadowColor = UIColor.black.cgColor
        innerView.layer.shadowOpacity = 0.2
        innerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        innerView.layer.shadowRadius = 4
        innerView.isUserInteractionEnabled = true
        
        addSubview(innerView)
        
        // Configure label
        countLabel.font = .boldSystemFont(ofSize: 14)
        countLabel.textColor = .black
        countLabel.textAlignment = .center
        countLabel.frame = innerView.bounds
        
        innerView.addSubview(countLabel)
    }
    
    private func setupSVGBackground() {
        guard let url = Bundle.main.url(forResource: "markerShape", withExtension: "svg"),
              let svgData = try? Data(contentsOf: url),
              let svgString = String(data: svgData, encoding: .utf8) else {
            print("⚠️ markerShape.svg not found in bundle - using fallback appearance")
            return
        }
        
        // Parse SVG to extract path data
        guard let pathData = extractSVGPathData(from: svgString) else {
            print("⚠️ No valid path found in markerShape.svg")
            return
        }
        
        // Convert SVG path data to UIBezierPath
        guard let bezierPath = UIBezierPath(svgPath: pathData) else {
            print("⚠️ Failed to parse SVG path data")
            return
        }
        
        // Get original SVG bounds
        let originalBounds = bezierPath.bounds
        
        // Resize frame to match SVG aspect ratio
        let svgSize = originalBounds.size
        self.frame = CGRect(x: 0, y: 0, width: svgSize.width, height: svgSize.height)
        
        // Create shape layer with SVG path
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = bezierPath.cgPath
        shapeLayer.fillColor = UIColor.systemYellow.cgColor  // Default fill
        shapeLayer.strokeColor = UIColor.clear.cgColor
        
        // Add shadow to shape layer
        shapeLayer.shadowColor = UIColor.black.cgColor
        shapeLayer.shadowOpacity = 0.2
        shapeLayer.shadowOffset = CGSize(width: 0, height: 2)
        shapeLayer.shadowRadius = 4
        
        // Add to view
        self.layer.insertSublayer(shapeLayer, at: 0)
        self.svgShapeLayer = shapeLayer
        
        // Update innerView to match SVG size
        innerView.frame = CGRect(x: 0, y: 0, width: svgSize.width, height: svgSize.height)
        
        print("✅ SVG background loaded successfully: \(svgSize)")
    }
    
    private func extractSVGPathData(from svgString: String) -> String? {
        // Simple regex to extract d="..." from first <path> element
        guard let regex = try? NSRegularExpression(pattern: "<path[^>]*\\sd=\"([^\"]+)\"", options: []),
              let match = regex.firstMatch(in: svgString, range: NSRange(svgString.startIndex..., in: svgString)) else {
            return nil
        }
        
        let nsString = svgString as NSString
        return nsString.substring(with: match.range(at: 1))
    }
    
    private func setupGestures() {
        tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        if let tapGesture = tapGesture {
            addGestureRecognizer(tapGesture)
        }
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(panGesture)
        
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPressGesture.minimumPressDuration = 0.6
        addGestureRecognizer(longPressGesture)
        
        // Pan should require long press to fail
        panGesture.require(toFail: longPressGesture)
    }
    
    @objc private func handleTap() {
        guard marker.type == .counter else { return }
        
        // Don't increment if already complete
        guard marker.currentCount < target else { return }
        
        // Increment counter
        marker.increment()
        
        // Notify callback
        onCountChanged?(marker.currentCount)
        
        // Check for completion
        if marker.currentCount >= target {
            completeCounter()
        } else {
            // Update UI
            updateLabel()
            flashFeedback()
        }
        
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let overlay = superview else { return }
        
        switch gesture.state {
        case .began:
            print("🔵 .began - setting isDragging = true")
            isDragging = true
            print("🔵 .began - isDragging is now: \(isDragging)")
            // Set dragging state synchronously before animation
            onSetDragging?()
            
            print("🔵 Pan began on SimpleMarkerView - marker id: \(marker.id)")
            let dragScale = currentZoomScale * 1.25
            UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8) {
                self.transform = CGAffineTransform(scaleX: dragScale, y: dragScale)
            }
            onDragStarted?()
        case .changed:
            print("🔵 Pan changed - translation: \(gesture.translation(in: overlay))")
            let delta = gesture.translation(in: overlay)
            // Update center directly - repositionMarkerViews() is skipping us
            center = CGPoint(x: center.x + delta.x, y: center.y + delta.y)
            gesture.setTranslation(.zero, in: overlay)
        case .ended, .cancelled:
            // Restore scale animation to zoom scale (not identity)
            UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8) {
                self.transform = CGAffineTransform(scaleX: self.currentZoomScale, y: self.currentZoomScale)
            }
            // Clear dragging flag after animation completes
            isDragging = false
            // Notify end - this will trigger repositioning to snap to PDF coordinates
            onDragEnded?(center)
        default:
            break
        }
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        
        // Show removal confirmation
        let alert = UIAlertController(
            title: "Remove Marker",
            message: "Are you sure you want to remove this marker?",
            preferredStyle: .actionSheet
        )
        
        alert.addAction(UIAlertAction(title: "Remove Marker", style: .destructive) { [weak self] _ in
            self?.onRemove?()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // Configure popover for iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = self
            popover.sourceRect = bounds
        }
        
        // Present from view controller
        presentingViewController?.present(alert, animated: true)
        
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }
    
    private func completeCounter() {
        // Remove tap gesture
        if let tapGesture = tapGesture {
            removeGestureRecognizer(tapGesture)
            self.tapGesture = nil
        }
        
        // Animate color change
        UIView.animate(withDuration: 0.3) {
            if let svgLayer = self.svgShapeLayer {
                // Change SVG fill to green
                svgLayer.fillColor = UIColor.systemGreen.cgColor
            } else {
                // Fallback: change innerView background
                self.innerView.backgroundColor = .systemGreen
            }
        }
        
        // Replace label with checkmark
        countLabel.removeFromSuperview()
        
        let checkmark = UIImageView(image: UIImage(systemName: "checkmark"))
        checkmark.tintColor = .white
        checkmark.contentMode = .scaleAspectFit
        checkmark.frame = innerView.bounds.insetBy(dx: 8, dy: 8)
        innerView.addSubview(checkmark)
        checkmarkImageView = checkmark
        
        // Success haptic
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.success)
    }
    
    private func updateAppearance() {
        if marker.type == .counter {
            if marker.currentCount >= target {
                // Complete state
                if let svgLayer = svgShapeLayer {
                    svgLayer.fillColor = UIColor.systemGreen.cgColor
                } else {
                    innerView.backgroundColor = .systemGreen
                }
                
                countLabel.removeFromSuperview()
                
                let checkmark = UIImageView(image: UIImage(systemName: "checkmark"))
                checkmark.tintColor = .white
                checkmark.contentMode = .scaleAspectFit
                checkmark.frame = innerView.bounds.insetBy(dx: 8, dy: 8)
                innerView.addSubview(checkmark)
                checkmarkImageView = checkmark
                
                // Remove tap gesture if complete
                if let tapGesture = tapGesture {
                    removeGestureRecognizer(tapGesture)
                    self.tapGesture = nil
                }
            } else {
                // Incomplete state
                if let svgLayer = svgShapeLayer {
                    svgLayer.fillColor = UIColor.systemYellow.cgColor
                } else {
                    innerView.backgroundColor = .systemYellow
                }
                updateLabel()
            }
        } else {
            // Note type - keep original appearance (no SVG)
            innerView.backgroundColor = .systemOrange
            updateLabel()
        }
    }
    
    private func updateLabel() {
        if marker.type == .counter {
            countLabel.text = "\(marker.currentCount)/\(target)"
        } else {
            countLabel.text = "📌"
        }
    }
    
    private func flashFeedback() {
        UIView.animate(withDuration: 0.15, animations: {
            if let svgLayer = self.svgShapeLayer {
                svgLayer.fillColor = UIColor.systemGreen.cgColor
            } else {
                self.innerView.backgroundColor = .systemGreen
            }
        }) { _ in
            UIView.animate(withDuration: 0.3) {
                // Restore to yellow (not complete yet)
                if let svgLayer = self.svgShapeLayer {
                    svgLayer.fillColor = UIColor.systemYellow.cgColor
                } else {
                    self.innerView.backgroundColor = .systemYellow
                }
            }
        }
    }
    
    func updateCount() {
        updateLabel()
    }
}

// MARK: - UIBezierPath SVG Extension

extension UIBezierPath {
    /// Create a UIBezierPath from SVG path data string
    /// Supports basic SVG commands: M, L, C, Q, H, V, Z
    convenience init?(svgPath: String) {
        self.init()
        
        var currentPoint = CGPoint.zero
        var startPoint = CGPoint.zero
        
        // Parse path data - split by command letters
        let scanner = Scanner(string: svgPath)
        scanner.charactersToBeSkipped = CharacterSet.whitespacesAndNewlines
        
        while !scanner.isAtEnd {
            // Try to scan a command letter
            var commandChar: NSString?
            if scanner.scanCharacters(from: CharacterSet.letters, into: &commandChar),
               let command = commandChar as String?, let firstChar = command.first {
                
                switch firstChar {
                case "M": // Move to
                    if let x = scanNumber(scanner), let y = scanNumber(scanner) {
                        let point = CGPoint(x: x, y: y)
                        move(to: point)
                        currentPoint = point
                        startPoint = point
                    }
                    
                case "L": // Line to
                    if let x = scanNumber(scanner), let y = scanNumber(scanner) {
                        let point = CGPoint(x: x, y: y)
                        addLine(to: point)
                        currentPoint = point
                    }
                    
                case "H": // Horizontal line
                    if let x = scanNumber(scanner) {
                        let point = CGPoint(x: x, y: currentPoint.y)
                        addLine(to: point)
                        currentPoint = point
                    }
                    
                case "V": // Vertical line
                    if let y = scanNumber(scanner) {
                        let point = CGPoint(x: currentPoint.x, y: y)
                        addLine(to: point)
                        currentPoint = point
                    }
                    
                case "C": // Cubic bezier
                    if let cp1x = scanNumber(scanner), let cp1y = scanNumber(scanner),
                       let cp2x = scanNumber(scanner), let cp2y = scanNumber(scanner),
                       let endx = scanNumber(scanner), let endy = scanNumber(scanner) {
                        let cp1 = CGPoint(x: cp1x, y: cp1y)
                        let cp2 = CGPoint(x: cp2x, y: cp2y)
                        let end = CGPoint(x: endx, y: endy)
                        addCurve(to: end, controlPoint1: cp1, controlPoint2: cp2)
                        currentPoint = end
                    }
                    
                case "Q": // Quadratic bezier
                    if let cpx = scanNumber(scanner), let cpy = scanNumber(scanner),
                       let endx = scanNumber(scanner), let endy = scanNumber(scanner) {
                        let cp = CGPoint(x: cpx, y: cpy)
                        let end = CGPoint(x: endx, y: endy)
                        addQuadCurve(to: end, controlPoint: cp)
                        currentPoint = end
                    }
                    
                case "Z", "z": // Close path
                    close()
                    currentPoint = startPoint
                    
                default:
                    break
                }
            }
        }
    }
    
    private func scanNumber(_ scanner: Scanner) -> CGFloat? {
        // Skip commas and whitespace
        scanner.charactersToBeSkipped = CharacterSet(charactersIn: ", \t\n")
        
        var value: Double = 0
        if scanner.scanDouble(&value) {
            return CGFloat(value)
        }
        return nil
    }
}

// MARK: - Term Highlight Annotation
class MarkerAnnotation: PDFAnnotation {
    let marker: Marker
    
    init(bounds: CGRect, marker: Marker) {
        self.marker = marker
        super.init(bounds: bounds, forType: .circle, withProperties: nil)
        
        // Configure appearance
        self.color = markerColor()
        self.backgroundColor = markerColor()
        self.interiorColor = markerColor()
        
        // Make it interactive
        self.isReadOnly = false
        
        // Add border
        self.border = PDFBorder()
        self.border?.lineWidth = 3
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(with box: PDFDisplayBox, in context: CGContext) {
        // Ensure we have a valid context
        guard UIGraphicsGetCurrentContext() != nil else { return }
        
        // Save graphics state
        context.saveGState()
        
        // Get the bounds for drawing
        let drawBounds = self.bounds
        
        // Draw circular background
        let circlePath = UIBezierPath(ovalIn: drawBounds)
        context.setFillColor(markerColor().cgColor)
        context.addPath(circlePath.cgPath)
        context.fillPath()
        
        // Draw shadow
        context.setShadow(offset: CGSize(width: 0, height: 2), blur: 4, color: UIColor.black.withAlphaComponent(0.3).cgColor)
        
        // Restore graphics state before drawing text/icons
        context.restoreGState()
        
        // Push context for text/icon drawing
        UIGraphicsPushContext(context)
        
        // Draw content (icon or counter text)
        if marker.type == .counter {
            // Draw counter text
            let text = "\(marker.currentCount)/\(marker.targetCount)"
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .bold),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraphStyle
            ]
            let attributedString = NSAttributedString(string: text, attributes: attributes)
            let textSize = attributedString.size()
            
            let textRect = CGRect(
                x: drawBounds.midX - textSize.width / 2,
                y: drawBounds.midY - textSize.height / 2,
                width: textSize.width,
                height: textSize.height
            )
            
            attributedString.draw(in: textRect)
        } else {
            // Draw note icon (simplified - just a small rectangle representing a note)
            let iconSize: CGFloat = 26
            let iconRect = CGRect(
                x: drawBounds.midX - iconSize / 2,
                y: drawBounds.midY - iconSize / 2,
                width: iconSize,
                height: iconSize
            )
            
            // Draw a simplified note icon using paths
            context.setStrokeColor(UIColor.white.cgColor)
            context.setLineWidth(2)
            
            let notePath = UIBezierPath(rect: iconRect.insetBy(dx: 4, dy: 4))
            notePath.stroke()
            
            // Draw lines representing text
            let lineY1 = iconRect.midY - 2
            let lineY2 = iconRect.midY + 2
            let lineX1 = iconRect.minX + 6
            let lineX2 = iconRect.maxX - 6
            
            let line1 = UIBezierPath()
            line1.move(to: CGPoint(x: lineX1, y: lineY1))
            line1.addLine(to: CGPoint(x: lineX2, y: lineY1))
            line1.stroke()
            
            let line2 = UIBezierPath()
            line2.move(to: CGPoint(x: lineX1, y: lineY2))
            line2.addLine(to: CGPoint(x: lineX2, y: lineY2))
            line2.stroke()
        }
        
        // Pop context
        UIGraphicsPopContext()
    }
    
    private func markerColor() -> UIColor {
        switch marker.color {
        case "blue": return .systemBlue
        case "green": return .systemGreen
        case "red": return .systemRed
        case "yellow": return .systemOrange
        case "purple": return .systemPurple
        default: return marker.type == .counter ? .systemBlue : .systemOrange
        }
    }
}


