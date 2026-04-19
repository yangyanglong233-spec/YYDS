//
//  TextHighlightingView.swift
//  Yarn&Yarn
//
//  Created by Yangyang Long on 3/16/26.
//

import SwiftUI
import Vision
import PDFKit
import AVKit

/// A view that overlays detected text with highlighting for knitting terminology
struct TextHighlightingOverlay: View {
    let image: UIImage
    let geometry: GeometryProxy
    let scale: CGFloat
    
    @State private var detectedTerms: [DetectedTerm] = []
    @State private var selectedTerm: KnittingGlossary.Term?
    @State private var showingDefinition = false
    @State private var isProcessing = false
    
    var body: some View {
        ZStack {
            // Highlight boxes for each detected term
            ForEach(detectedTerms) { detectedTerm in
                Rectangle()
                    .strokeBorder(highlightColor(for: detectedTerm.term.category), lineWidth: 2)
                    .background(highlightColor(for: detectedTerm.term.category).opacity(0.2))
                    .frame(
                        width: detectedTerm.boundingBox.width * geometry.size.width * scale,
                        height: detectedTerm.boundingBox.height * geometry.size.height * scale
                    )
                    .position(
                        x: detectedTerm.boundingBox.midX * geometry.size.width,
                        y: (1 - detectedTerm.boundingBox.midY) * geometry.size.height
                    )
                    .onTapGesture {
                        selectedTerm = detectedTerm.term
                        showingDefinition = true
                    }
            }
            
            // Processing indicator
            if isProcessing {
                VStack {
                    Spacer()
                    HStack {
                        ProgressView()
                            .padding(8)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                        Spacer()
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            detectText(in: image)
        }
        .sheet(isPresented: $showingDefinition) {
            if let term = selectedTerm {
                GlossaryTermDetailView(term: term)
                    .presentationDetents([.medium, .large])
            }
        }
    }
    
    /// Returns a color for highlighting based on term category
    private func highlightColor(for category: KnittingGlossary.Category) -> Color {
        switch category {
        case .basicStitches:
            return .yellow
        case .increases, .decreases:
            return .orange
        case .castOn, .bindOff:
            return .green
        case .cables:
            return .purple
        case .colorwork:
            return .pink
        case .lace:
            return .cyan
        default:
            return .blue
        }
    }
    
    private func detectText(in image: UIImage) {
        guard let cgImage = image.cgImage else { return }
        
        isProcessing = true
        
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                DispatchQueue.main.async {
                    isProcessing = false
                }
                return
            }
            
            var foundTerms: [DetectedTerm] = []
            
            for observation in observations {
                guard let topCandidate = observation.topCandidates(1).first else {
                    continue
                }
                
                let text = topCandidate.string
                
                // Use the glossary to find all knitting terms in this text observation
                let matches = KnittingGlossary.findTerms(in: text)
                
                for match in matches {
                    let detectedTerm = DetectedTerm(
                        text: match.term.abbreviation,
                        term: match.term,
                        boundingBox: observation.boundingBox
                    )
                    foundTerms.append(detectedTerm)
                }
            }
            
            DispatchQueue.main.async {
                detectedTerms = foundTerms
                isProcessing = false
            }
        }
        
        request.recognitionLevel = VNRequestTextRecognitionLevel.accurate
        request.usesLanguageCorrection = false
        
        // Process in background
        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }
}

// MARK: - Improved Text Highlighting Overlay (accounts for image frame and transformations)
struct ImprovedTextHighlightingOverlay: View {
    let image: UIImage
    let imageFrame: CGRect
    let scale: CGFloat
    let offset: CGSize
    
    @State private var detectedTerms: [DetectedTerm] = []
    @State private var selectedTerm: KnittingGlossary.Term?
    @State private var showingDefinition = false
    @State private var isProcessing = false
    @State private var allTextBoxes: [VNRecognizedTextObservation] = [] // For debugging
    
    // Set to true to show ALL text boxes (for debugging positioning)
    private let showDebugBoxes = false
    
    var body: some View {
        // Canvas for absolute positioning within image bounds
        Canvas { context, size in
            // Debug: Draw ALL detected text boxes in red (if enabled)
            if showDebugBoxes {
                for observation in allTextBoxes {
                    let visionBox = observation.boundingBox
                    let x = visionBox.origin.x * imageFrame.width
                    let y = (1 - visionBox.origin.y - visionBox.height) * imageFrame.height
                    let width = visionBox.width * imageFrame.width
                    let height = visionBox.height * imageFrame.height
                    
                    let rect = CGRect(x: x, y: y, width: width, height: height)
                    
                    // Red border for all text
                    context.stroke(
                        Path(rect),
                        with: .color(.red.opacity(0.5)),
                        lineWidth: 1
                    )
                }
            }
            
            // Draw term highlights (knitting terms only)
            for detectedTerm in detectedTerms {
                let visionBox = detectedTerm.boundingBox
                
                // Convert Vision coordinates (bottom-left origin, normalized 0-1)
                // to SwiftUI coordinates (top-left origin, in points)
                let x = visionBox.origin.x * imageFrame.width
                let y = (1 - visionBox.origin.y - visionBox.height) * imageFrame.height
                let width = visionBox.width * imageFrame.width
                let height = visionBox.height * imageFrame.height
                
                let rect = CGRect(x: x, y: y, width: width, height: height)
                let color = highlightColor(for: detectedTerm.term.category)
                
                // Draw filled background
                context.fill(
                    Path(roundedRect: rect, cornerRadius: 4),
                    with: .color(color.opacity(0.25))
                )
                
                // Draw border
                context.stroke(
                    Path(roundedRect: rect, cornerRadius: 4),
                    with: .color(color),
                    lineWidth: 2.5
                )
            }
        }
        .frame(width: imageFrame.width, height: imageFrame.height)
        .contentShape(Rectangle()) // Make entire area tappable
        .simultaneousGesture(
            // Use simultaneousGesture to handle taps on highlights
            DragGesture(minimumDistance: 0)
                .onEnded { value in
                    let tapLocation = value.location
                    
                    // Check if tap is on any highlight
                    for detectedTerm in detectedTerms {
                        let visionBox = detectedTerm.boundingBox
                        let x = visionBox.origin.x * imageFrame.width
                        let y = (1 - visionBox.origin.y - visionBox.height) * imageFrame.height
                        let width = visionBox.width * imageFrame.width
                        let height = visionBox.height * imageFrame.height
                        
                        let highlightRect = CGRect(x: x, y: y, width: width, height: height)
                        
                        if highlightRect.contains(tapLocation) {
                            // Haptic feedback
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            
                            selectedTerm = detectedTerm.term
                            showingDefinition = true
                            break
                        }
                    }
                }
        )
        .overlay(alignment: .topLeading) {
            // Processing indicator
            if isProcessing {
                HStack {
                    ProgressView()
                        .padding(12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .shadow(radius: 4)
                    Spacer()
                }
                .padding()
            }
        }
        .onAppear {
            detectText(in: image)
        }
        .sheet(isPresented: $showingDefinition) {
            if let term = selectedTerm {
                GlossaryTermDetailView(term: term)
                    .presentationDetents([.medium, .large])
            }
        }
    }
    
    /// Returns a color for highlighting based on term category
    private func highlightColor(for category: KnittingGlossary.Category) -> Color {
        switch category {
        case .basicStitches:
            return .yellow
        case .increases, .decreases:
            return .orange
        case .castOn, .bindOff:
            return .green
        case .cables:
            return .purple
        case .colorwork:
            return .pink
        case .lace:
            return .cyan
        default:
            return .blue
        }
    }
    
    private func detectText(in image: UIImage) {
        guard let cgImage = image.cgImage else { return }
        
        isProcessing = true
        
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                DispatchQueue.main.async {
                    isProcessing = false
                }
                return
            }
            
            var foundTerms: [DetectedTerm] = []
            
            print("🔍 DEBUG: Found \(observations.count) text observations in image")
            print("🔍 DEBUG: Image frame: \(self.imageFrame)")
            
            for observation in observations {
                guard let topCandidate = observation.topCandidates(1).first else {
                    continue
                }
                
                let text = topCandidate.string
                
                // Use the glossary to find all knitting terms in this text observation
                let matches = KnittingGlossary.findTerms(in: text)
                
                // For each match, try to get its precise bounding box
                for match in matches {
                    // Get the range of the term in the string (already a Swift Range)
                    let swiftRange = match.range
                    
                    // Try to get character-level bounding box for this specific term
                    if let termBox = try? topCandidate.boundingBox(for: swiftRange)?.boundingBox {
                        // Use the precise bounding box for just this term
                        print("🔍 DEBUG: Found term '\(match.term.abbreviation)' at precise box: \(termBox)")
                        
                        let detectedTerm = DetectedTerm(
                            text: match.term.abbreviation,
                            term: match.term,
                            boundingBox: termBox
                        )
                        foundTerms.append(detectedTerm)
                    } else {
                        // Fallback to full line box if we can't get character-level
                        print("⚠️ WARNING: Could not get precise box for '\(match.term.abbreviation)', using line box")
                        let detectedTerm = DetectedTerm(
                            text: match.term.abbreviation,
                            term: match.term,
                            boundingBox: observation.boundingBox
                        )
                        foundTerms.append(detectedTerm)
                    }
                }
            }
            
            print("🔍 DEBUG: Total knitting terms highlighted: \(foundTerms.count)")
            
            DispatchQueue.main.async {
                allTextBoxes = observations // Save for debug visualization
                detectedTerms = foundTerms
                isProcessing = false
            }
        }
        
        request.recognitionLevel = VNRequestTextRecognitionLevel.accurate
        request.usesLanguageCorrection = false
        
        // Process in background
        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }
}

struct DetectedTerm: Identifiable {
    let id = UUID()
    let text: String
    let term: KnittingGlossary.Term
    let boundingBox: CGRect
}

/// Detailed view for a glossary term
struct GlossaryTermDetailView: View {
    let term: KnittingGlossary.Term
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Term header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(term.abbreviation)
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                            
                            Spacer()
                            
                            CategoryBadge(category: term.category)
                        }
                        
                        Text(term.fullName)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    Divider()
                    
                    // Tutorial Video
                    if let videoName = term.tutorialVideoName {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tutorial")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            
                            TutorialVideoPlayer(videoName: videoName)
                                .frame(height: 250)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal)
                    }
                    
                    // Definition
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Definition")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        Text(term.definition)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal)
                    
                    // Aliases (if any)
                    if !term.aliases.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Also known as")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            
                            FlowLayout(spacing: 8) {
                                ForEach(term.aliases, id: \.self) { alias in
                                    Text(alias)
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(.quaternary, in: Capsule())
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 20)
                }
            }
            .navigationTitle("Glossary")
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
/// Badge showing the category of a term
struct CategoryBadge: View {
    let category: KnittingGlossary.Category
    
    var body: some View {
        Text(category.rawValue)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(categoryColor.opacity(0.2))
            .foregroundStyle(categoryColor)
            .clipShape(Capsule())
    }
    
    var categoryColor: Color {
        switch category {
        case .basicStitches: return .yellow
        case .increases, .decreases: return .orange
        case .castOn, .bindOff: return .green
        case .cables: return .purple
        case .colorwork: return .pink
        case .lace: return .cyan
        default: return .blue
        }
    }
}

/// Video player for stitch tutorials
struct TutorialVideoPlayer: View {
    let videoName: String
    @State private var player: AVPlayer?
    @State private var showError = false
    
    var body: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
                    .onAppear {
                        // Loop the video
                        NotificationCenter.default.addObserver(
                            forName: .AVPlayerItemDidPlayToEndTime,
                            object: player.currentItem,
                            queue: .main
                        ) { _ in
                            player.seek(to: .zero)
                            player.play()
                        }
                        player.play()
                    }
                    .onDisappear {
                        player.pause()
                    }
            } else if showError {
                VStack(spacing: 12) {
                    HeroIcon(.videoSlash, size: 48)
                        .foregroundStyle(.secondary)
                    
                    Text("Tutorial video not available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("Coming soon!")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.quaternary.opacity(0.3))
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.quaternary.opacity(0.3))
            }
        }
        .onAppear {
            loadVideo()
        }
    }
    
    private func loadVideo() {
        // Try to load from bundle
        if let videoURL = Bundle.main.url(forResource: videoName, withExtension: "mp4") {
            player = AVPlayer(url: videoURL)
        } else if let videoURL = Bundle.main.url(forResource: videoName, withExtension: "mov") {
            player = AVPlayer(url: videoURL)
        } else if let videoURL = Bundle.main.url(forResource: videoName, withExtension: "gif") {
            // For GIFs, you might want to use a different approach
            // For now, show error
            showError = true
        } else {
            // Video not found - show placeholder
            showError = true
        }
    }
}

/// Section showing related terms in the same category
struct RelatedTermsSection: View {
    let currentTerm: KnittingGlossary.Term
    
    var relatedTerms: [KnittingGlossary.Term] {
        KnittingGlossary.terms(in: currentTerm.category)
            .filter { $0.abbreviation != currentTerm.abbreviation }
            .prefix(5)
            .map { $0 }
    }
    
    var body: some View {
        if !relatedTerms.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Related Terms")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(relatedTerms, id: \.abbreviation) { term in
                        HStack {
                            Text(term.abbreviation)
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            
                            Text("—")
                                .foregroundStyle(.tertiary)
                            
                            Text(term.fullName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }
}

/// Simple flow layout for wrapping items
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            let position = result.positions[index]
            subview.place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

// MARK: - Knitting Glossary
/// Comprehensive knitting terminology glossary
struct KnittingGlossary {
    
    // MARK: - Term Structure
    
    struct Term: Identifiable, Hashable {
        let id = UUID()
        let abbreviation: String
        let fullName: String
        let definition: String
        let category: Category
        let aliases: [String]
        let tutorialVideoName: String? // Name of video file (without extension)
        
        init(_ abbreviation: String, _ fullName: String, _ definition: String, category: Category, aliases: [String] = [], tutorialVideo: String? = nil) {
            self.abbreviation = abbreviation
            self.fullName = fullName
            self.definition = definition
            self.category = category
            self.aliases = aliases
            self.tutorialVideoName = tutorialVideo
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(abbreviation)
        }
        
        static func == (lhs: Term, rhs: Term) -> Bool {
            lhs.abbreviation == rhs.abbreviation
        }
    }
    
    enum Category: String, CaseIterable {
        case basicStitches = "Basic Stitches"
        case castOn = "Cast On Methods"
        case bindOff = "Bind Off Methods"
        case increases = "Increases"
        case decreases = "Decreases"
        case cables = "Cable Techniques"
        case colorwork = "Colorwork"
        case texture = "Texture Techniques"
        case lace = "Lace"
        case construction = "Construction & Shaping"
        case inTheRound = "Working in the Round"
        case finishing = "Finishing"
        case yarnTools = "Yarn & Tools"
        case patternReading = "Reading Patterns"
    }
    
    // MARK: - All Terms
    
    static let allTerms: [Term] = [
        // Basic Stitches
        Term("k", "knit", "Insert the right needle through the front of the stitch from left to right, wrap yarn around the needle, and pull through to create a new stitch.", category: .basicStitches, tutorialVideo: "k"),
        Term("p", "purl", "Insert the right needle through the front of the stitch from right to left, wrap yarn around the needle, and pull through to create a new stitch on the reverse side.", category: .basicStitches, tutorialVideo: "p"),
        Term("k2tog", "knit two together", "Knit two stitches together as one to create a right-leaning decrease.", category: .basicStitches, tutorialVideo: "k2tog"),
        Term("p2tog", "purl two together", "Purl two stitches together as one to decrease.", category: .basicStitches, tutorialVideo: "p2tog"),
        Term("ssk", "slip slip knit", "Slip two stitches knitwise one at a time, then insert left needle through front loops and knit together for a left-leaning decrease.", category: .basicStitches, tutorialVideo: "ssk"),
        Term("ssp", "slip slip purl", "Slip two stitches knitwise, return to left needle, then purl together through back loops.", category: .basicStitches, tutorialVideo: "ssp"),
        Term("kfb", "knit front and back", "Knit into the front and back of the same stitch to increase by one stitch (leaves a small purl bump).", category: .basicStitches, tutorialVideo: "kfb"),
        Term("pfb", "purl front and back", "Purl into the front and back of the same stitch to increase by one stitch.", category: .basicStitches, tutorialVideo: "pfb"),
        Term("yo", "yarn over", "Wrap yarn around the needle to create a new stitch and a decorative eyelet or hole.", category: .basicStitches, tutorialVideo: "yo"),
        Term("sl", "slip stitch", "Move a stitch from left to right needle without working it, usually done purlwise unless stated otherwise.", category: .basicStitches, aliases: ["sl1"], tutorialVideo: "sl"),
        Term("sl1k", "slip 1 knitwise", "Slip one stitch as if to knit.", category: .basicStitches, tutorialVideo: "sl1k"),
        Term("sl1p", "slip 1 purlwise", "Slip one stitch as if to purl.", category: .basicStitches, tutorialVideo: "sl1p"),
        Term("k tbl", "knit through back loop", "Knit into the back loop of the stitch instead of the front, creating a twisted stitch.", category: .basicStitches, aliases: ["ktbl"], tutorialVideo: "ktbl"),
        Term("p tbl", "purl through back loop", "Purl into the back loop of the stitch instead of the front.", category: .basicStitches, aliases: ["ptbl"], tutorialVideo: "ptbl"),
        Term("m1pl", "make 1 purlwise left", "With the left-hand needle, pick up the strand between the stitch just worked and the next stitch from front to back, then purl through the back loop. A left-leaning increase worked on the purl side.", category: .basicStitches),
        Term("m1pr", "make 1 purlwise right", "With the left-hand needle, pick up the strand between the stitch just worked and the next stitch from back to front, then purl through the front loop. A right-leaning increase worked on the purl side.", category: .basicStitches),
        Term("sl1 wyif", "slip 1 with yarn in front", "Move the working yarn to the front of the work, slip the next stitch purlwise without working it, leaving the yarn in front.", category: .basicStitches),
        
        // Cast On Methods
        Term("CO", "cast on", "Create the initial stitches on the needle to begin knitting.", category: .castOn),
        Term("long-tail cast on", "long-tail cast on", "Versatile, stretchy cast on method using a long tail of yarn; most common all-purpose cast on.", category: .castOn),
        Term("cable cast on", "cable cast on", "Creates a firm edge by knitting between stitches; good for buttonbands and mid-row cast ons.", category: .castOn),
        Term("backward loop cast on", "backward loop cast on", "Quick cast on method using loops; often used for mid-row additions.", category: .castOn),
        Term("Judy's magic cast on", "Judy's magic cast on", "Creates stitches on two needles simultaneously; popular for toe-up socks.", category: .castOn),
        Term("provisional cast on", "provisional cast on", "Temporary cast on that can be removed later to pick up live stitches.", category: .castOn),
        Term("Turkish cast on", "Turkish cast on", "Another method for toe-up socks that creates a seamless toe.", category: .castOn),
        Term("German twisted cast on", "German twisted cast on", "Very stretchy cast on; excellent for cuffs and edges that need elasticity.", category: .castOn),
        
        // Bind Off Methods
        Term("BO", "bind off", "Secure the stitches to finish an edge by passing one stitch over another.", category: .bindOff, aliases: ["cast off"]),
        Term("standard bind off", "standard bind off", "Basic bind off method; can be tight, so consider using a larger needle.", category: .bindOff),
        Term("stretchy bind off", "stretchy bind off", "Bind off using k2tog tbl repeatedly; good for necklines and cuffs.", category: .bindOff),
        Term("Jeny's surprisingly stretchy bind off", "Jeny's surprisingly stretchy bind off", "Yarn over before each stitch before binding off to create maximum stretch.", category: .bindOff, aliases: ["JSSBO"]),
        Term("three-needle bind off", "three-needle bind off", "Joins two sets of live stitches together while binding off; commonly used for shoulders and seams.", category: .bindOff),
        Term("i-cord bind off", "i-cord bind off", "Creates a neat rolled edge by working an i-cord along the bind off edge.", category: .bindOff),
        
        // Increases
        Term("M1L", "make one left", "Left-leaning invisible increase: lift bar between stitches and knit through back loop.", category: .increases),
        Term("M1R", "make one right", "Right-leaning invisible increase: lift bar between stitches and knit through front loop.", category: .increases),
        Term("M1P", "make one purlwise", "Make one increase worked purlwise.", category: .increases),
        Term("LLI", "left lifted increase", "Nearly invisible left-leaning increase by knitting into the stitch below.", category: .increases),
        Term("RLI", "right lifted increase", "Nearly invisible right-leaning increase by knitting into the stitch below.", category: .increases),
        
        // Decreases
        Term("k3tog", "knit three together", "Knit three stitches together as one to create a double right-leaning decrease.", category: .decreases),
        Term("sssk", "slip slip slip knit", "Triple left-leaning decrease: slip three stitches knitwise, then knit together.", category: .decreases),
        Term("skp", "slip knit pass", "Slip one stitch, knit one, pass slipped stitch over; left-leaning decrease (older method).", category: .decreases),
        Term("cdd", "central double decrease", "Centered double decrease: slip two together knitwise, k1, pass both slipped stitches over.", category: .decreases, aliases: ["s2kp2", "sl2-k1-p2sso"]),
        
        // Cable Techniques
        Term("C4F", "cable 4 front", "Cable 4 stitches with held stitches to front (creates left-leaning cable).", category: .cables),
        Term("C4B", "cable 4 back", "Cable 4 stitches with held stitches to back (creates right-leaning cable).", category: .cables),
        Term("C6F", "cable 6 front", "Cable 6 stitches with held stitches to front.", category: .cables),
        Term("C6B", "cable 6 back", "Cable 6 stitches with held stitches to back.", category: .cables),
        Term("cn", "cable needle", "Short double-pointed needle used to hold stitches temporarily while cabling.", category: .cables),
        Term("rope cable", "rope cable", "Simple twisted cable created by consistently crossing stitches in the same direction.", category: .cables),
        Term("honeycomb cable", "honeycomb cable", "Cable pattern created by alternating front and back crosses.", category: .cables),
        Term("travelling stitch", "travelling stitch", "Single stitch that moves diagonally across the fabric using cable techniques.", category: .cables),
        
        // Colorwork
        Term("Fair Isle", "Fair Isle", "Traditional stranded colorwork using two colors per row with floats carried on the wrong side.", category: .colorwork),
        Term("intarsia", "intarsia", "Colorwork technique using separate yarn for each color block; no floats on the back.", category: .colorwork),
        Term("float", "float", "Strand of yarn carried across the back of the work between color changes in stranded colorwork.", category: .colorwork),
        Term("mosaic knitting", "mosaic knitting", "Slip-stitch colorwork technique using only one color per row.", category: .colorwork),
        Term("duplicate stitch", "duplicate stitch", "Embroidered stitch that mimics a knit stitch; used to add color after knitting.", category: .colorwork),
        Term("stranded colorwork", "stranded colorwork", "Technique of carrying two or more yarns across a row, creating floats on the back.", category: .colorwork),
        
        // Texture Techniques
        Term("seed stitch", "seed stitch", "Textured pattern alternating k1, p1 with stitches offset each row for a bumpy texture.", category: .texture),
        Term("moss stitch", "moss stitch", "Similar to seed stitch but offset every two rows instead of every row.", category: .texture),
        Term("ribbing", "ribbing", "Vertical columns of knit and purl stitches that align vertically (k1p1, k2p2, etc.) for elastic fabric.", category: .texture),
        Term("garter stitch", "garter stitch", "Knit every row when working flat; creates horizontal ridges and lies flat.", category: .texture),
        Term("stockinette", "stockinette stitch", "Knit on right side, purl on wrong side; creates smooth V's on one side and bumps on the other.", category: .texture, aliases: ["St st"]),
        Term("reverse stockinette", "reverse stockinette", "Stockinette stitch with the purl side facing out as the right side.", category: .texture),
        Term("brioche", "brioche", "Slip stitch and yarn over pattern creating a squishy, highly elastic ribbed fabric.", category: .texture),
        Term("brk", "brioche knit", "Knit the slipped stitch together with its yarn over in brioche knitting.", category: .texture),
        Term("brp", "brioche purl", "Purl the slipped stitch together with its yarn over in brioche knitting.", category: .texture),
        Term("tuck stitch", "tuck stitch", "Elongated stitch pulled up from rows below for texture.", category: .texture),
        Term("drop stitch", "drop stitch", "Intentionally dropped stitch that ladders down for an open, lacy effect.", category: .texture),
        
        // Lace
        Term("eyelet", "eyelet", "Single decorative hole created with a yarn over and corresponding decrease.", category: .lace),
        Term("lace", "lace", "Open, airy fabric created using yarn overs and decreases to form decorative patterns.", category: .lace),
        Term("nupps", "nupps", "Small bobble-like clusters of stitches common in Estonian lace; worked by knitting multiple times into one stitch.", category: .lace),
        Term("bobble", "bobble", "Rounded 3D texture created by working multiple increases and decreases in the same spot.", category: .lace),
        Term("picot", "picot", "Small decorative point along an edge, typically made with yarn overs during bind off.", category: .lace),
        
        // Construction & Shaping
        Term("short rows", "short rows", "Partial rows that don't go all the way across, used to add shape like shoulder slopes or bust darts.", category: .construction),
        Term("w&t", "wrap and turn", "Traditional short row method where you wrap the working yarn around a stitch before turning.", category: .construction, aliases: ["wrap and turn"]),
        Term("GSR", "German short rows", "Short row method using a double stitch; creates clean, easy-to-work turns.", category: .construction),
        Term("raglan", "raglan", "Diagonal seam construction from underarm to neck; can be worked flat or in the round.", category: .construction),
        Term("set-in sleeve", "set-in sleeve", "Sleeve with a shaped cap that fits into an armhole.", category: .construction),
        Term("saddle shoulder", "saddle shoulder", "Construction where the sleeve extends across the shoulder.", category: .construction),
        Term("yoke", "yoke", "Upper body section that joins sleeves and body, often worked in one piece.", category: .construction),
        Term("steek", "steek", "Extra stitches added to colorwork so you can cut the knitting open (for cardigans).", category: .construction),
        Term("gusset", "gusset", "Triangular section adding ease and shaping, common in thumbs, heels, and underarms.", category: .construction),
        Term("seaming", "seaming", "Joining separate knitted pieces together using techniques like mattress stitch.", category: .construction),
        
        // Working in the Round
        Term("BOR", "beginning of round", "The starting point of each round when working circularly.", category: .inTheRound),
        Term("magic loop", "magic loop", "Technique for working small circumferences on a long circular needle by pulling out loops of cable.", category: .inTheRound),
        Term("DPN", "double-pointed needle", "Short needle with points on both ends, used in sets for circular knitting.", category: .inTheRound),
        Term("DPNS", "double-pointed needles", "Plural of DPN; typically comes in sets of 4 or 5.", category: .inTheRound),
        Term("join", "join", "Connecting cast on stitches to begin working in the round.", category: .inTheRound),
        
        // Finishing
        Term("mattress stitch", "mattress stitch", "Invisible seaming technique for joining side edges of knitted pieces.", category: .finishing),
        Term("Kitchener stitch", "Kitchener stitch", "Grafting technique that joins live stitches invisibly, commonly used for sock toes.", category: .finishing, aliases: ["grafting"]),
        Term("blocking", "blocking", "Process of wetting or steaming finished knitting to even out stitches and set the final shape.", category: .finishing),
        Term("wet blocking", "wet blocking", "Soaking knitted fabric in water, pressing out excess, then pinning to desired shape to dry.", category: .finishing),
        Term("steam blocking", "steam blocking", "Using a steam iron held above the fabric to set the shape without touching the iron to the work.", category: .finishing),
        Term("spray blocking", "spray blocking", "Misting knitted fabric with water and pinning to shape.", category: .finishing),
        Term("weaving in ends", "weaving in ends", "Securing yarn tails on the wrong side by threading through stitches.", category: .finishing),
        Term("picking up stitches", "picking up stitches", "Inserting needle along an edge to create new stitches for additional knitting.", category: .finishing),
        
        // Yarn & Tools
        Term("WPI", "wraps per inch", "Measurement used to determine yarn weight by wrapping around a ruler.", category: .yarnTools),
        Term("yardage", "yardage", "Length of yarn in a skein, typically measured in yards or meters.", category: .yarnTools),
        Term("skein", "skein", "Twisted coil of yarn ready to use without additional winding.", category: .yarnTools),
        Term("hank", "hank", "Loose loop of yarn that must be wound into a ball before use.", category: .yarnTools),
        Term("cake", "cake", "Center-pull ball of yarn wound on a swift or ball winder.", category: .yarnTools),
        Term("swift", "swift", "Umbrella-like tool for holding hanks while winding into balls.", category: .yarnTools),
        Term("gauge", "gauge", "Number of stitches and rows per inch or 4 inches; critical for achieving correct fit.", category: .yarnTools),
        Term("gauge swatch", "gauge swatch", "Test knitting used to check gauge before starting a project.", category: .yarnTools),
        Term("ease", "ease", "Difference between body measurement and finished garment size.", category: .yarnTools),
        Term("positive ease", "positive ease", "Garment is larger than body measurement for a relaxed fit.", category: .yarnTools),
        Term("negative ease", "negative ease", "Garment is smaller than body measurement for a fitted, stretchy fit.", category: .yarnTools),
        Term("ply", "ply", "Individual strands twisted together to make yarn.", category: .yarnTools),
        Term("singles", "singles", "Unplied yarn consisting of a single strand.", category: .yarnTools),
        Term("superwash", "superwash", "Wool treated to be machine washable without felting.", category: .yarnTools),
        
        // Pattern Reading
        Term("RS", "right side", "The public-facing or front side of the knitted fabric.", category: .patternReading),
        Term("WS", "wrong side", "The private or back side of the knitted fabric.", category: .patternReading),
        Term("rep", "repeat", "Instruction to repeat a section of the pattern.", category: .patternReading),
        Term("pm", "place marker", "Put a stitch marker on the needle to mark a position.", category: .patternReading),
        Term("sm", "slip marker", "Move a stitch marker from left to right needle without working it.", category: .patternReading),
        Term("rm", "remove marker", "Take a stitch marker off the needle.", category: .patternReading),
        Term("st", "stitch", "A single loop on the needle.", category: .patternReading),
        Term("sts", "stitches", "Multiple loops on the needle.", category: .patternReading),
    ]
    
    // MARK: - Lookup Methods
    
    /// Dictionary for quick lookup by abbreviation (case-insensitive)
    static let termsByAbbreviation: [String: Term] = {
        var dict: [String: Term] = [:]
        for term in allTerms {
            dict[term.abbreviation.lowercased()] = term
            for alias in term.aliases {
                dict[alias.lowercased()] = term
            }
        }
        return dict
    }()
    
    /// Get all terms sorted by abbreviation length (longest first) for better pattern matching
    static let termsSortedByLength: [Term] = {
        allTerms.sorted { $0.abbreviation.count > $1.abbreviation.count }
    }()
    
    /// Get all unique abbreviations and aliases for pattern matching
    static let allAbbreviations: [String] = {
        var abbrevs: [String] = []
        for term in allTerms {
            abbrevs.append(term.abbreviation)
            abbrevs.append(contentsOf: term.aliases)
        }
        return abbrevs.sorted { $0.count > $1.count }
    }()
    
    /// Look up a term by its abbreviation (case-insensitive)
    static func term(for abbreviation: String) -> Term? {
        termsByAbbreviation[abbreviation.lowercased()]
    }
    
    /// Get all terms in a specific category
    static func terms(in category: Category) -> [Term] {
        allTerms.filter { $0.category == category }
    }
    
    /// Check if a string matches any knitting term
    static func isKnittingTerm(_ text: String) -> Bool {
        termsByAbbreviation[text.lowercased()] != nil
    }
    
    /// Find all knitting terms in a given text string
    static func findTerms(in text: String) -> [(term: Term, range: Range<String.Index>)] {
        var foundTerms: [(term: Term, range: Range<String.Index>)] = []
        var searchText = text
        var processedRanges: [Range<String.Index>] = []
        
        // First pass: Find compound terms (e.g., sl1yo, k2togyo)
        let compoundMatches = findCompoundTerms(in: searchText)
        foundTerms.append(contentsOf: compoundMatches)
        processedRanges.append(contentsOf: compoundMatches.map { $0.range })
        
        // Second pass: Find individual terms (skip already processed ranges)
        for abbreviation in allAbbreviations {
            var searchRange = searchText.startIndex..<searchText.endIndex
            
            while let range = searchText.range(
                of: abbreviation,
                options: [.caseInsensitive],
                range: searchRange
            ) {
                // Skip if this range overlaps with a compound term
                let overlaps = processedRanges.contains { processedRange in
                    range.overlaps(processedRange)
                }
                
                if !overlaps {
                    // Check if this is a valid term (with or without numbers)
                    let (isValid, extendedRange) = isStandaloneTermWithOptionalNumber(in: searchText, range: range)
                    
                    if isValid {
                        if let term = term(for: abbreviation) {
                            foundTerms.append((term: term, range: extendedRange))
                            processedRanges.append(extendedRange)
                        }
                    }
                }
                
                guard range.upperBound < searchText.endIndex else { break }
                searchRange = range.upperBound..<searchText.endIndex
            }
        }
        
        return foundTerms.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }
    
    /// Find compound terms like "sl1yo", "k2togyo", etc.
    /// These are combinations of multiple terms written together
    private static func findCompoundTerms(in text: String) -> [(term: Term, range: Range<String.Index>)] {
        var compounds: [(term: Term, range: Range<String.Index>)] = []
        
        // Common compound patterns
        let compoundPatterns: [(pattern: String, components: [String])] = [
            // slip + number + yarn over
            ("sl1yo", ["sl1", "yo"]),
            ("sl2yo", ["sl", "yo"]),
            ("slyo", ["sl", "yo"]),
            
            // knit/purl + number + yarn over
            ("k1yo", ["k1", "yo"]),
            ("k2yo", ["k2", "yo"]),
            ("p1yo", ["p1", "yo"]),
            ("p2yo", ["p2", "yo"]),
            
            // decrease + yarn over
            ("k2togyo", ["k2tog", "yo"]),
            ("sskyo", ["ssk", "yo"]),
            ("p2togyo", ["p2tog", "yo"]),
            
            // yarn over + decrease (common in lace)
            ("yok2tog", ["yo", "k2tog"]),
            ("yossk", ["yo", "ssk"]),
            
            // slip slip knit variations
            ("ssk2", ["ssk"]),
            ("sssk", ["sssk"]),
        ]
        
        var searchRange = text.startIndex..<text.endIndex
        
        for (pattern, components) in compoundPatterns {
            var currentRange = text.startIndex..<text.endIndex
            
            while let range = text.range(
                of: pattern,
                options: [.caseInsensitive],
                range: currentRange
            ) {
                // Verify word boundaries
                let (isValid, _) = isStandaloneTermWithOptionalNumber(in: text, range: range)
                
                if isValid {
                    // Use the first component as the primary term for the definition
                    if let firstComponent = components.first,
                       let term = term(for: firstComponent) {
                        compounds.append((term: term, range: range))
                    }
                }
                
                guard range.upperBound < text.endIndex else { break }
                currentRange = range.upperBound..<text.endIndex
            }
        }
        
        return compounds
    }
    
    /// Check if a term is standalone and optionally followed by a number (e.g., "k1", "p2tog3")
    /// Returns (isValid, extendedRange) where extendedRange includes any trailing numbers
    private static func isStandaloneTermWithOptionalNumber(in text: String, range: Range<String.Index>) -> (Bool, Range<String.Index>) {
        // Check character before term
        let beforeIndex = text.index(range.lowerBound, offsetBy: -1, limitedBy: text.startIndex)
        let beforeIsValid = beforeIndex.map {
            let char = text[$0]
            return char.isWhitespace || char.isPunctuation || char == "(" || char == ","
        } ?? true
        
        if !beforeIsValid {
            return (false, range)
        }
        
        // Check character(s) after term - allow digits
        var afterIndex = range.upperBound
        var extendedRange = range
        
        // Consume any trailing digits (e.g., k1, k2, p2tog3, etc.)
        while afterIndex < text.endIndex, text[afterIndex].isNumber {
            afterIndex = text.index(after: afterIndex)
            extendedRange = range.lowerBound..<afterIndex
        }
        
        // Now check if the character after the number (or after the term if no number) is valid
        let afterIsValid = afterIndex == text.endIndex || {
            let char = text[afterIndex]
            return char.isWhitespace || char.isPunctuation || char == ")" || char == ","
        }()
        
        return (afterIsValid, extendedRange)
    }
}


