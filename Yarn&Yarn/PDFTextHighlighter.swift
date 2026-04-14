//
//  PDFTextHighlighter.swift
//  Yarn&Yarn
//
//  Created by Yangyang Long on 3/17/26.
//

import PDFKit
import SwiftUI
import Vision

/// Coordinator for managing PDF text highlighting
class PDFTextHighlighter: NSObject, PDFViewDelegate {
    weak var pdfView: PDFView?
    var highlightedAnnotations: [PDFAnnotation] = []
    var onTermTapped: ((KnittingGlossary.Term) -> Void)?
    
    private var isProcessing = false
    
    init(pdfView: PDFView) {
        self.pdfView = pdfView
        super.init()
        pdfView.delegate = self
    }
    
    /// Highlight all knitting terms in the PDF
    func highlightAllTerms() {
        guard let document = pdfView?.document, !isProcessing else { return }
        
        isProcessing = true
        
        // Process each page
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var annotationsByPage: [Int: [PDFAnnotation]] = [:]
            
            for pageIndex in 0..<document.pageCount {
                guard let page = document.page(at: pageIndex) else { continue }
                let annotations = self.createHighlightAnnotations(for: page)
                if !annotations.isEmpty {
                    annotationsByPage[pageIndex] = annotations
                }
            }
            
            DispatchQueue.main.async {
                self.applyAnnotations(annotationsByPage, document: document)
                self.isProcessing = false
            }
        }
    }
    
    /// Create highlight annotations for a PDF page
    private func createHighlightAnnotations(for page: PDFPage) -> [PDFAnnotation] {
        guard let pageText = page.string else { return [] }
        
        var annotations: [PDFAnnotation] = []
        
        // Find all knitting terms in the page text
        let foundTerms = KnittingGlossary.findTerms(in: pageText)
        
        for (term, range) in foundTerms {
            // Convert string range to NSRange
            let nsRange = NSRange(range, in: pageText)
            
            // Try to get the selection for this range
            if let selection = page.selection(for: nsRange) {
                let bounds = selection.bounds(for: page)
                
                // Create a highlight annotation
                let annotation = PDFAnnotation(
                    bounds: bounds,
                    forType: .highlight,
                    withProperties: nil
                )
                
                // Set color based on category with transparency
                let color = highlightColor(for: term.category).withAlphaComponent(0.3)
                annotation.color = color
                
                // Store term info in annotation's user info
                annotation.userName = term.abbreviation
                
                annotations.append(annotation)
            }
        }
        
        return annotations
    }
    
    /// Apply annotations to the PDF
    private func applyAnnotations(_ annotationsByPage: [Int: [PDFAnnotation]], document: PDFDocument) {
        // Remove old annotations
        removeAllHighlights()
        
        // Add annotations to their respective pages
        for (pageIndex, pageAnnotations) in annotationsByPage {
            guard let page = document.page(at: pageIndex) else { continue }
            
            for annotation in pageAnnotations {
                page.addAnnotation(annotation)
                highlightedAnnotations.append(annotation)
            }
        }
    }
    
    /// Remove all highlight annotations
    func removeAllHighlights() {
        guard let document = pdfView?.document else { return }
        
        for annotation in highlightedAnnotations {
            // Find which page this annotation is on
            for pageIndex in 0..<document.pageCount {
                guard let page = document.page(at: pageIndex) else { continue }
                if page.annotations.contains(annotation) {
                    page.removeAnnotation(annotation)
                }
            }
        }
        
        highlightedAnnotations.removeAll()
    }
    
    /// Get highlight color for a category
    private func highlightColor(for category: KnittingGlossary.Category) -> NSUIColor {
        switch category {
        case .basicStitches:
            return NSUIColor.systemYellow
        case .increases, .decreases:
            return NSUIColor.systemOrange
        case .castOn, .bindOff:
            return NSUIColor.systemGreen
        case .cables:
            return NSUIColor.systemPurple
        case .colorwork:
            return NSUIColor.systemPink
        case .lace:
            return NSUIColor.systemCyan
        default:
            return NSUIColor.systemBlue
        }
    }
}

// Platform-specific type alias
#if os(iOS)
typealias NSUIColor = UIColor
#else
typealias NSUIColor = NSColor
#endif
