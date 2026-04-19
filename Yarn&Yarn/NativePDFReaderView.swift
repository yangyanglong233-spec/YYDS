//
//  NativePDFReaderView.swift
//  Yarn&Yarn
//
//  Created by Yangyang Long on 3/19/26.
//

import SwiftUI
import PDFKit
import SwiftData
import Combine

// MARK: - Lens Bridge

/// Reference-type bridge so the UIKit coordinator can vend a query closure to SwiftUI.
/// `queryTermsAt` is set once in `makeUIView`; SwiftUI calls it whenever the lens moves.
final class LensBridge: ObservableObject {
    /// Set once in makeUIView; called with center in UIKit window coordinates.
    var queryTermsAt: ((CGPoint, CGFloat) -> [(KnittingGlossary.Term, CGRect)])?
    /// Set by SwiftUI via onGeometryChange; the global (window) origin of the lens GeometryReader.
    var lensOriginInWindow: CGPoint = .zero
    /// Returns 1 or 2 columns for the given zero-based page number.
    var detectColumnCount: ((Int) -> Int)?
}

// MARK: - Reading Position Marker View

final class ReadingPositionMarkerView: UIView {
    /// Called continuously during drag (overlay-space position of the tip).
    var onDragged: ((CGPoint) -> Void)?
    /// Called when the drag ends so the coordinator can persist the final position.
    var onDropped: (() -> Void)?

    private var posAtDragStart: CGPoint = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = .clear
        isUserInteractionEnabled = true

        // Cursor arrow icon
        let cfg = UIImage.SymbolConfiguration(pointSize: 30, weight: .semibold)
        let img = UIImage(systemName: "cursorarrow", withConfiguration: cfg)
        let iv = UIImageView(image: img)
        iv.tintColor = .systemBlue
        iv.contentMode = .scaleAspectFit
        iv.frame = bounds
        iv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(iv)

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.35
        layer.shadowRadius = 3
        layer.shadowOffset = CGSize(width: 1, height: 2)

        // Anchor at the cursor tip (top-left of the arrow glyph)
        layer.anchorPoint = CGPoint(x: 0.12, y: 0.06)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(pan)
    }

    var isDragging: Bool {
        gestureRecognizers?.compactMap { $0 as? UIPanGestureRecognizer }
            .contains { $0.state == .changed || $0.state == .began } ?? false
    }

    @objc private func handlePan(_ g: UIPanGestureRecognizer) {
        guard let sv = superview else { return }
        let t = g.translation(in: sv)
        switch g.state {
        case .began:
            posAtDragStart = layer.position
        case .changed:
            let newPos = CGPoint(x: posAtDragStart.x + t.x, y: posAtDragStart.y + t.y)
            layer.position = newPos
            onDragged?(newPos)
        case .ended, .cancelled:
            onDropped?()
        default: break
        }
    }
}

// MARK: - Term Position

/// Lightweight record of where a knitting term appears on a PDF page.
/// Stored only in coordinator memory — never written to SwiftData.
struct TermPosition {
    let term: KnittingGlossary.Term
    let pageNumber: Int
    let normalizedRect: CGRect   // origin and size as fractions of the page mediaBox
}

/// A native SwiftUI-based PDF reader with full control over interactions
/// This uses PDFKit's PDFView for reliable zoom and scroll
struct NativePDFReaderView: View {
    let pdfDocument: PDFDocument
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
                lensBridge: lensBridge,
                selectedTerm: $selectedTerm,
                showingTermDetail: $showingTermDetail,
                isLoadingTerm: $isLoadingTerm,
                selectedMarker: $selectedMarker,
                showingMarkerPopup: $showingMarkerPopup,
                visibleCounterIDs: visibleCounterIDs,
                viewportCenter: viewportCenter,
                hasReadingPosition: hasReadingPosition,
                isReadingMarkerVisible: isReadingMarkerVisible,
                readingPositionPage: readingPositionPage,
                readingPositionX: readingPositionX,
                readingPositionY: readingPositionY,
                onReadingPositionMoved: onReadingPositionMoved
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
            // Counter markers no longer open a popup — counting happens in the toolbar panel.
            // Only note markers open an edit sheet from the PDF.
            if let selectedMarker, selectedMarker.type == .note {
                MarkerNoteEditorView(marker: selectedMarker)
                    .presentationDetents([.medium, .large])
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
    let lensBridge: LensBridge
    @Binding var selectedTerm: KnittingGlossary.Term?
    @Binding var showingTermDetail: Bool
    @Binding var isLoadingTerm: Bool
    @Binding var selectedMarker: Marker?
    @Binding var showingMarkerPopup: Bool
    var visibleCounterIDs: Binding<Set<UUID>>
    var viewportCenter: Binding<CGPoint>
    // Reading position ("I am here" marker)
    var hasReadingPosition: Bool
    var isReadingMarkerVisible: Bool
    var readingPositionPage: Int
    var readingPositionX: Double
    var readingPositionY: Double
    var onReadingPositionMoved: ((Int, Double, Double) -> Void)?

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

        // Allow PDFView's built-in pinch-to-zoom and scroll recognizers to fire even when
        // a SwiftUI gesture overlay (.simultaneousGesture on the lens) is also active.
        pdfView.gestureRecognizers?.forEach { $0.cancelsTouchesInView = false }

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
        context.coordinator.visibleCounterIDsBinding = visibleCounterIDs
        context.coordinator.viewportCenterBinding = viewportCenter
        
        // Store the target page — applied from inside the first PDFViewPageChanged handler
        // once the view is laid out and pdfView.go(to:) actually works.
        context.coordinator.initialPage = currentPage
        context.coordinator.hasRestoredInitialPage = false
        
        // Wire up lens bridge
        lensBridge.queryTermsAt = { [weak coordinator = context.coordinator] center, radius in
            coordinator?.termsInLens(center: center, radius: radius) ?? []
        }
        lensBridge.detectColumnCount = { [weak coordinator = context.coordinator] pageNumber in
            coordinator?.detectColumnCount(pageNumber: pageNumber) ?? 1
        }

        // Set up "I am here" reading position marker
        context.coordinator.onReadingPositionMoved = onReadingPositionMoved
        context.coordinator.hasReadingPosition  = hasReadingPosition
        context.coordinator.readingPositionPage = readingPositionPage
        context.coordinator.readingPositionX    = readingPositionX
        context.coordinator.readingPositionY    = readingPositionY
        if hasReadingPosition {
            context.coordinator.setupReadingPositionMarker()
            context.coordinator.readingPositionView?.isHidden = !isReadingMarkerVisible
        }
        
        // Add highlights
        context.coordinator.addHighlights(page: currentPage)
        
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

            // First notification is PDFKit's own "document loaded at page 0" event.
            // Intercept it to jump to the restored page instead.
            if !context.coordinator.hasRestoredInitialPage {
                context.coordinator.hasRestoredInitialPage = true
                let target = context.coordinator.initialPage
                if target > 0, let targetPDFPage = document.page(at: target) {
                    // View is now laid out — go(to:) works and will fire a second notification.
                    pdfView.go(to: targetPDFPage)
                } else {
                    // Restoring to page 0 — nothing to jump, proceed normally.
                    context.coordinator.updateCurrentPage(index)
                    context.coordinator.addHighlights(page: index)
                    context.coordinator.rebuildMarkerViews(markers: context.coordinator.instructionDocument.markers)
                }
                return
            }

            context.coordinator.updateCurrentPage(index)
            context.coordinator.addHighlights(page: index)
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
        context.coordinator.visibleCounterIDsBinding = visibleCounterIDs
        context.coordinator.viewportCenterBinding = viewportCenter
        
        context.coordinator.instructionDocument = instructionDocument
        
        // Update to new page if changed externally
        guard let currentPDFPage = pdfView.currentPage else {
            print("DEBUG: updateUIView - no current page yet, scheduling for later")
            // Page not loaded yet, try again after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let page = pdfView.currentPage {
                    let index = self.document.index(for: page)
                    context.coordinator.addHighlights(page: index)
                    context.coordinator.rebuildMarkerViews(markers: self.instructionDocument.markers)
                    context.coordinator.repositionMarkerViews()
                }
            }
            return
        }
        
        // In vertical continuous scroll mode the user scrolls freely — do not
        // call pdfView.go(to:) here, as it would reset the scroll position
        // whenever updateUIView is called (e.g. on scale binding updates).
        // Page tracking is handled exclusively by the PDFViewPageChanged notification.
        
        // Check if any markers across all pages have changed
        let allMarkers = instructionDocument.markers
        let incomingIDs = Set(allMarkers.map { $0.id })
        let existingIDs = Set(context.coordinator.markerViewMap.keys)

        let shouldRebuild = incomingIDs != existingIDs
        print("🟡 updateUIView called - will rebuild: \(shouldRebuild)")

        if shouldRebuild {
            // Markers were added or removed — full rebuild needed
            context.coordinator.rebuildMarkerViews(markers: allMarkers)
        } else {
            // Same markers — sync color + count labels (toolbar / edit sheet may have changed them)
            context.coordinator.refreshAppearances(markers: allMarkers)
            context.coordinator.refreshCountLabels(markers: allMarkers)
            context.coordinator.repositionMarkerViews()
        }

        // Suppress unused variable warning
        _ = currentPDFPage

        // Sync reading position marker when project changes externally
        context.coordinator.onReadingPositionMoved = onReadingPositionMoved
        // Always sync visibility (user may just have toggled the tab)
        context.coordinator.readingPositionView?.isHidden = !isReadingMarkerVisible
        let posChanged = context.coordinator.hasReadingPosition != hasReadingPosition
            || context.coordinator.readingPositionPage != readingPositionPage
            || abs(context.coordinator.readingPositionX - readingPositionX) > 0.001
            || abs(context.coordinator.readingPositionY - readingPositionY) > 0.001
        if posChanged {
            context.coordinator.hasReadingPosition  = hasReadingPosition
            context.coordinator.readingPositionPage = readingPositionPage
            context.coordinator.readingPositionX    = readingPositionX
            context.coordinator.readingPositionY    = readingPositionY
            if hasReadingPosition {
                if context.coordinator.readingPositionView == nil {
                    context.coordinator.setupReadingPositionMarker()
                }
                context.coordinator.readingPositionView?.isHidden = !isReadingMarkerVisible
            } else {
                context.coordinator.readingPositionView?.removeFromSuperview()
                context.coordinator.readingPositionView = nil
            }
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
        let modelContext: ModelContext
        
        // Term positions stored in memory only
        var termPositions: [TermPosition] = []
        
        // Marker views keyed by marker ID for efficient repositioning
        var markerViewMap: [UUID: SimpleMarkerView] = [:]
        private var currentMarkers: [Marker] = []
        
        // CADisplayLink for continuous tracking
        private var displayLink: CADisplayLink?
        
        // Track which marker is currently being dragged
        var draggingMarkerID: UUID?
        var draggingMarkerView: SimpleMarkerView?

        // Visible counter tracking — pushed to SwiftUI via binding when the set changes
        var visibleCounterIDsBinding: Binding<Set<UUID>>?
        var lastVisibleCounterIDs: Set<UUID> = []

        // Viewport center — normalized (0-1) coords on the current page, updated each frame
        var viewportCenterBinding: Binding<CGPoint>?
        private var lastViewportCenter: CGPoint = CGPoint(x: 0.5, y: 0.5)
        
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
        
        /// Page to scroll to on first load (seeded from project.lastReadPage).
        var initialPage: Int = 0
        /// Becomes true after the first PDFViewPageChanged fires and we've dispatched go(to:).
        var hasRestoredInitialPage = false

        // MARK: - Reading position marker
        var readingPositionView: ReadingPositionMarkerView?
        var hasReadingPosition = false
        var readingPositionPage: Int = 0
        var readingPositionX: Double = 0.5
        var readingPositionY: Double = 0.5
        var onReadingPositionMoved: ((Int, Double, Double) -> Void)?

        /// Per-page column count cache (1 or 2). Populated lazily.
        var columnCountCache: [Int: Int] = [:]

        func updateCurrentPage(_ page: Int) {
            currentPage = page
        }

        // MARK: - Column detection

        func detectColumnCount(pageNumber: Int) -> Int {
            if let cached = columnCountCache[pageNumber] { return cached }
            guard let page = pdfView?.document?.page(at: pageNumber) else { return 1 }
            let result = Self.analyseColumns(page: page)
            columnCountCache[pageNumber] = result
            return result
        }

        private static func analyseColumns(page: PDFPage) -> Int {
            let pageWidth = page.bounds(for: .mediaBox).width
            guard pageWidth > 0 else { return 1 }
            // Select all text on the page and split into lines
            let fullBounds = page.bounds(for: .mediaBox)
            guard let sel = page.selection(for: fullBounds) else { return 1 }
            let lines = sel.selectionsByLine() as? [PDFSelection] ?? []
            guard lines.count >= 6 else { return 1 }

            // Classify each line's midX as left-half or right-half
            var left = 0; var right = 0; var mid = 0
            for line in lines {
                let b = line.bounds(for: page)
                guard b.width > pageWidth * 0.05 else { continue } // skip tiny fragments
                let mx = b.midX / pageWidth
                if      mx < 0.40 { left  += 1 }
                else if mx > 0.60 { right += 1 }
                else              { mid   += 1 }
            }
            let total = left + right + mid
            guard total >= 6 else { return 1 }
            // Two-column: most lines are clearly in left or right half, few cross the centre
            let centredRatio = Double(mid) / Double(total)
            return centredRatio < 0.20 ? 2 : 1
        }

        // MARK: - Reading position marker management

        func setupReadingPositionMarker() {
            guard let overlayView else { return }
            // Remove any stale marker
            readingPositionView?.removeFromSuperview()

            let marker = ReadingPositionMarkerView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
            marker.onDragged = { [weak self] pos in
                guard let self else { return }
                // Live-update stored position so repositionMarkerViews stays in sync
                if let norm = self.overlayPointToNormalised(pos) {
                    self.readingPositionPage = norm.page
                    self.readingPositionX    = norm.x
                    self.readingPositionY    = norm.y
                }
            }
            marker.onDropped = { [weak self] in
                guard let self else { return }
                self.onReadingPositionMoved?(self.readingPositionPage,
                                             self.readingPositionX,
                                             self.readingPositionY)
            }
            overlayView.addSubview(marker)
            readingPositionView = marker
        }

        func repositionReadingPositionMarker() {
            guard hasReadingPosition,
                  let marker = readingPositionView,
                  let pdfView,
                  let overlayView,
                  let containerView = overlayView.superview,
                  let page = pdfView.document?.page(at: readingPositionPage) else { return }

            if !marker.isDragging {
                let pageBounds = page.bounds(for: .mediaBox)
                let pdfPoint   = CGPoint(x: readingPositionX * pageBounds.width,
                                         y: readingPositionY * pageBounds.height)
                let inPDFView  = pdfView.convert(pdfPoint, from: page)
                let inContainer = pdfView.convert(inPDFView, to: containerView)
                let inOverlay  = overlayView.convert(inContainer, from: containerView)
                marker.layer.position = inOverlay
            }
        }

        /// Helper: convert an overlay-space point (tip of the cursor) back to normalised PDF coords.
        func overlayPointToNormalised(_ point: CGPoint) -> (page: Int, x: Double, y: Double)? {
            guard let pdfView,
                  let overlayView,
                  let containerView = overlayView.superview else { return nil }
            let inContainer = overlayView.convert(point, to: containerView)
            let inPDFView   = containerView.convert(inContainer, to: pdfView)
            guard let page = pdfView.page(for: inPDFView, nearest: true) else { return nil }
            let inPage      = pdfView.convert(inPDFView, to: page)
            let bounds      = page.bounds(for: .mediaBox)
            let pageNumber  = pdfView.document?.index(for: page) ?? 0
            let x = max(0, min(1, Double(inPage.x / bounds.width)))
            let y = max(0, min(1, Double(inPage.y / bounds.height)))
            return (pageNumber, x, y)
        }

        /// `ReadingPositionMarkerView` is a UIView — expose isDragging via its gesture.
        private var markerIsDragging: Bool {
            readingPositionView?.gestureRecognizers?
                .compactMap { $0 as? UIPanGestureRecognizer }
                .contains { $0.state == .changed } ?? false
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
                  pdfView != nil else {
                print("DEBUG: Cannot rebuild markers - overlayView or pdfView is nil")
                return
            }
            
            print("DEBUG: rebuildMarkerViews called with \(markers.count) markers")
            
            // Remove all existing marker views
            for (_, markerView) in markerViewMap {
                markerView.removeFromSuperview()
            }
            markerViewMap.removeAll()
            
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
                // Skip highlight markers - they are now handled via termPositions only
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
            
            // Initial positioning
            repositionMarkerViews()
        }
        
        /// Update count labels on existing counter badges when counts change from the toolbar panel
        func refreshCountLabels(markers: [Marker]) {
            for marker in markers where marker.type == .counter {
                markerViewMap[marker.id]?.refreshCount(marker.currentCount, target: marker.targetCount)
            }
        }

        /// Refresh the fill color of every marker badge (called when color is changed in the edit sheet)
        func refreshAppearances(markers: [Marker]) {
            for marker in markers {
                markerViewMap[marker.id]?.refreshAppearance()
            }
        }

        /// Reposition existing marker views (called continuously during zoom/scroll)
        @objc func repositionMarkerViews() {
            guard let pdfView = pdfView,
                  let overlayView = overlayView else { return }

            let scale = pdfView.scaleFactor

            // Only update scale binding when zoom actually changes — avoids triggering
            // updateUIView 60fps via the CADisplayLink, which would cause spurious page resets
            if abs(scale - self.scale) > 0.001 {
                updateScale(scale)
            }
            
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

            // Collect IDs of counter badges whose centre lies within the visible viewport.
            let panelHeight = overlayView.safeAreaInsets.bottom
            let visibleRect = CGRect(
                x: overlayView.bounds.minX,
                y: overlayView.bounds.minY,
                width: overlayView.bounds.width,
                height: overlayView.bounds.height - panelHeight
            )
            var visibleIDs = Set<UUID>()
            for (id, markerView) in markerViewMap {
                guard let marker = currentMarkers.first(where: { $0.id == id }),
                      marker.type == .counter else { continue }
                if visibleRect.contains(markerView.center) {
                    visibleIDs.insert(id)
                }
            }
            if visibleIDs != lastVisibleCounterIDs {
                lastVisibleCounterIDs = visibleIDs
                visibleCounterIDsBinding?.wrappedValue = visibleIDs
            }

            // Track viewport center in normalized page coordinates for new counter placement
            let viewCenter = CGPoint(x: pdfView.bounds.midX, y: pdfView.bounds.midY)
            if let page = pdfView.page(for: viewCenter, nearest: true) {
                let pointInPage = pdfView.convert(viewCenter, to: page)
                let pageBounds = page.bounds(for: .mediaBox)
                let nx = max(0, min(1, Double(pointInPage.x / pageBounds.width)))
                let ny = max(0, min(1, Double(pointInPage.y / pageBounds.height)))
                let newCenter = CGPoint(x: nx, y: ny)
                if abs(newCenter.x - lastViewportCenter.x) > 0.005 || abs(newCenter.y - lastViewportCenter.y) > 0.005 {
                    lastViewportCenter = newCenter
                    viewportCenterBinding?.wrappedValue = newCenter
                }
            }

            // Keep the "I am here" marker in sync with scroll/zoom
            repositionReadingPositionMarker()
        }

        // MARK: - Lens Query

        /// center and returned rects are all in UIKit window coordinates so they align
        /// with SwiftUI's .global coordinate space regardless of view hierarchy offsets
        /// (e.g. the page-indicator VStack row above NativePDFKitView).
        func termsInLens(center: CGPoint, radius: CGFloat) -> [(KnittingGlossary.Term, CGRect)] {
            guard let pdfView = pdfView,
                  let overlayView = overlayView,
                  let window = overlayView.window else { return [] }
            var result: [(KnittingGlossary.Term, CGRect)] = []
            for item in termPositions {
                guard let page = pdfView.document?.page(at: item.pageNumber) else { continue }
                let pb = page.bounds(for: .mediaBox)
                let pdfRect = CGRect(
                    x: item.normalizedRect.minX * pb.width,
                    y: item.normalizedRect.minY * pb.height,
                    width: item.normalizedRect.width * pb.width,
                    height: item.normalizedRect.height * pb.height
                )
                let inPDF = pdfView.convert(pdfRect, from: page)
                let inWindow = pdfView.convert(inPDF, to: window)
                let termCenter = CGPoint(x: inWindow.midX, y: inWindow.midY)
                let dist = hypot(termCenter.x - center.x, termCenter.y - center.y)
                if dist <= radius + max(inWindow.width, inWindow.height) / 2 {
                    result.append((item.term, inWindow))
                }
            }
            return result
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
            print("DEBUG: Tap on empty area or marker")
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
            // Annotations are no longer used for interaction
        }
        
        // MARK: - Highlights
        
        func addHighlights(page pageIndex: Int) {
            guard let page = document.page(at: pageIndex),
                  let pageText = page.string else { return }

            // Remove term positions for this page (will be replaced)
            termPositions.removeAll { $0.pageNumber == pageIndex }

            let foundTerms = KnittingGlossary.findTerms(in: pageText)
            let pageBounds = page.bounds(for: .mediaBox)

            for (term, range) in foundTerms {
                let nsRange = NSRange(range, in: pageText)
                if let selection = page.selection(for: nsRange) {
                    let bounds = selection.bounds(for: page)
                    let normalizedRect = CGRect(
                        x: bounds.origin.x / pageBounds.width,
                        y: bounds.origin.y / pageBounds.height,
                        width: bounds.width / pageBounds.width,
                        height: bounds.height / pageBounds.height
                    )
                    termPositions.append(TermPosition(
                        term: term,
                        pageNumber: pageIndex,
                        normalizedRect: normalizedRect
                    ))
                }
            }
        }
        
        func removeHighlights() {
            termPositions.removeAll()
            // Delete any legacy highlight Markers persisted to SwiftData
            let old = instructionDocument.markers.filter { $0.type == .highlight }
            for m in old { modelContext.delete(m) }
            try? modelContext.save()
        }
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
    var target: Int
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
    private var shapeLayer: CAShapeLayer?  // Custom shape for counter markers
    
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
        backgroundColor = .clear
        clipsToBounds = false
        isUserInteractionEnabled = true

        if marker.type == .counter {
            // Label-shaped badge — shape layer provides fill and shadow
            setupCounterShape()
            innerView.backgroundColor = .clear
            innerView.layer.cornerRadius = 0
        } else {
            // Note: rounded square centered in the 44×44 hit-test area
            innerView.frame = CGRect(x: 4, y: 4, width: 36, height: 36)
            innerView.backgroundColor = uiColorForMarker()
            innerView.layer.cornerRadius = 10
            innerView.layer.shadowColor = UIColor.black.cgColor
            innerView.layer.shadowOpacity = 0.2
            innerView.layer.shadowOffset = CGSize(width: 0, height: 2)
            innerView.layer.shadowRadius = 4
        }

        innerView.isUserInteractionEnabled = true
        addSubview(innerView)

        countLabel.font = .boldSystemFont(ofSize: 14)
        countLabel.textColor = marker.type == .counter ? uiTextColorForMarker() : .white
        countLabel.textAlignment = .center
        countLabel.frame = innerView.bounds
        innerView.addSubview(countLabel)
    }

    /// Builds the label-shaped counter badge:
    /// rounded TL / TR / BR corners (radius = height/2); sharp BL corner.
    private func setupCounterShape() {
        let W: CGFloat = 52
        let H: CGFloat = 28
        let R: CGFloat = H / 2   // = 14 — makes left & right ends fully rounded

        self.frame    = CGRect(x: 0, y: 0, width: W, height: H)
        innerView.frame = CGRect(x: 0, y: 0, width: W, height: H)

        // Path in UIKit coordinates (Y increases downward)
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: H))                          // BL — sharp
        path.addLine(to: CGPoint(x: 0, y: R))                       // left edge up
        path.addArc(withCenter: CGPoint(x: R, y: R),                // TL arc
                    radius: R, startAngle: .pi, endAngle: -.pi / 2, clockwise: true)
        path.addLine(to: CGPoint(x: W - R, y: 0))                   // top edge
        path.addArc(withCenter: CGPoint(x: W - R, y: R),            // TR arc
                    radius: R, startAngle: -.pi / 2, endAngle: 0, clockwise: true)
        path.addLine(to: CGPoint(x: W, y: H - R))                   // right edge down
        path.addArc(withCenter: CGPoint(x: W - R, y: H - R),        // BR arc
                    radius: R, startAngle: 0, endAngle: .pi / 2, clockwise: true)
        path.addLine(to: CGPoint(x: 0, y: H))                       // bottom edge
        path.close()

        let sl = CAShapeLayer()
        sl.path        = path.cgPath
        sl.fillColor   = uiColorForMarker().cgColor
        sl.shadowColor  = UIColor.black.cgColor
        sl.shadowOpacity = 0.22
        sl.shadowOffset  = CGSize(width: 0, height: 2)
        sl.shadowRadius  = 4
        sl.shadowPath    = path.cgPath   // explicit path = crisp shadow

        self.layer.insertSublayer(sl, at: 0)
        self.shapeLayer = sl
    }
    
    private func setupGestures() {
        // Counter badges are drag-only — counting happens in the toolbar panel
        if marker.type != .counter {
            tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            if let tapGesture = tapGesture {
                addGestureRecognizer(tapGesture)
            }
        }

        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(panGesture)

        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPressGesture.minimumPressDuration = 0.6
        addGestureRecognizer(longPressGesture)

        // Pan should require long press to fail
        panGesture.require(toFail: longPressGesture)
    }

    private func uiColorForMarker() -> UIColor {
        switch marker.color {
        case "sage":       return UIColor(red: 0.48, green: 0.68, blue: 0.56, alpha: 1)
        case "mauve":      return UIColor(red: 0.75, green: 0.52, blue: 0.66, alpha: 1)
        case "terracotta": return UIColor(red: 0.83, green: 0.45, blue: 0.35, alpha: 1)
        case "steel":      return UIColor(red: 0.42, green: 0.61, blue: 0.75, alpha: 1)
        case "gold":       return UIColor(red: 0.83, green: 0.66, blue: 0.26, alpha: 1)
        case "lavender":   return UIColor(red: 0.61, green: 0.56, blue: 0.77, alpha: 1)
        case "forest":     return UIColor(red: 0.42, green: 0.56, blue: 0.37, alpha: 1)
        case "rose":       return UIColor(red: 0.91, green: 0.65, blue: 0.65, alpha: 1)
        case "slate":      return UIColor(red: 0.48, green: 0.56, blue: 0.65, alpha: 1)
        case "amber":      return UIColor(red: 0.79, green: 0.42, blue: 0.18, alpha: 1)
        case "plum":       return UIColor(red: 0.48, green: 0.31, blue: 0.45, alpha: 1)
        case "linen":      return UIColor(red: 0.78, green: 0.72, blue: 0.60, alpha: 1)
        default:           return UIColor(red: 0.48, green: 0.68, blue: 0.56, alpha: 1)
        }
    }

    /// Returns black or white — whichever gives higher WCAG contrast against the badge fill.
    private func uiTextColorForMarker() -> UIColor {
        switch marker.color {
        case "plum": return .white
        default:     return .black
        }
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
            if let sl = self.shapeLayer {
                sl.fillColor = UIColor.systemGreen.cgColor
            } else {
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
        let markerColor = uiColorForMarker()
        if marker.type == .counter {
            if target > 0 && marker.currentCount >= target {
                // Complete — fill shape with marker color, show checkmark
                shapeLayer?.fillColor = markerColor.cgColor
                countLabel.removeFromSuperview()
                let checkmark = UIImageView(image: UIImage(systemName: "checkmark"))
                checkmark.tintColor = .white
                checkmark.contentMode = .scaleAspectFit
                checkmark.frame = innerView.bounds.insetBy(dx: 6, dy: 6)
                innerView.addSubview(checkmark)
                checkmarkImageView = checkmark
            } else {
                // Counting — fill with marker's assigned color
                shapeLayer?.fillColor = markerColor.cgColor
                updateLabel()
            }
        } else {
            innerView.backgroundColor = .systemOrange
            updateLabel()
        }
    }

    private func updateLabel() {
        if marker.type == .counter {
            countLabel.text = target > 0 ? "\(marker.currentCount)/\(target)" : "\(marker.currentCount)"
        } else {
            countLabel.text = "📌"
        }
    }

    private func flashFeedback() {
        // No-op — counter no longer increments from badge tap
    }

    func updateCount() {
        updateLabel()
    }

    /// Called from the coordinator when the marker's color changes in the edit sheet
    func refreshAppearance() {
        let color = uiColorForMarker()
        if let sl = shapeLayer {
            sl.fillColor = color.cgColor
        } else {
            innerView.backgroundColor = color
        }
        countLabel.textColor = uiTextColorForMarker()
    }

    /// Called from the coordinator when count or target changes in the toolbar panel.
    func refreshCount(_ count: Int, target: Int) {
        self.target = target

        if target > 0 && count >= target {
            // Complete state
            guard checkmarkImageView == nil else { return }
            countLabel.removeFromSuperview()
            let checkmark = UIImageView(image: UIImage(systemName: "checkmark"))
            checkmark.tintColor = .white
            checkmark.contentMode = .scaleAspectFit
            checkmark.frame = innerView.bounds.insetBy(dx: 6, dy: 6)
            innerView.addSubview(checkmark)
            checkmarkImageView = checkmark
        } else {
            // Counting state (also handles decrement back below target)
            if checkmarkImageView != nil {
                checkmarkImageView?.removeFromSuperview()
                checkmarkImageView = nil
                if countLabel.superview == nil {
                    innerView.addSubview(countLabel)
                    countLabel.frame = innerView.bounds
                }
            }
            countLabel.text = target > 0 ? "\(count)/\(target)" : "\(count)"
        }
    }
}

// MARK: - Term Highlight Annotation (legacy, kept for reference)
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
        guard UIGraphicsGetCurrentContext() != nil else { return }
        
        context.saveGState()
        
        let drawBounds = self.bounds
        
        let circlePath = UIBezierPath(ovalIn: drawBounds)
        context.setFillColor(markerColor().cgColor)
        context.addPath(circlePath.cgPath)
        context.fillPath()
        
        context.setShadow(offset: CGSize(width: 0, height: 2), blur: 4, color: UIColor.black.withAlphaComponent(0.3).cgColor)
        
        context.restoreGState()
        
        UIGraphicsPushContext(context)
        
        if marker.type == .counter {
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
            let iconSize: CGFloat = 26
            let iconRect = CGRect(
                x: drawBounds.midX - iconSize / 2,
                y: drawBounds.midY - iconSize / 2,
                width: iconSize,
                height: iconSize
            )
            
            context.setStrokeColor(UIColor.white.cgColor)
            context.setLineWidth(2)
            
            let notePath = UIBezierPath(rect: iconRect.insetBy(dx: 4, dy: 4))
            notePath.stroke()
            
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
