//
//  TextReaderView.swift
//  Yarn&Yarn
//
//  Created by Yangyang Long on 3/24/26.
//

import SwiftUI
import PDFKit

/// A text block with formatting metadata extracted from PDF
struct TextBlock: Identifiable {
    let id = UUID()
    var text: String
    var isHeading: Bool    // font size meaningfully larger than dominant body size
    var isItalic: Bool     // font name contains "italic" or "oblique"
}

/// A text-only reader view that displays extracted PDF content in a readable format
struct TextReaderView: View {
    let pdfDocument: PDFDocument
    
    @State private var blocks: [TextBlock] = []
    @State private var fontSize: CGFloat = 16
    
    private let minFontSize: CGFloat = 12
    private let maxFontSize: CGFloat = 28
    private let fontStep: CGFloat = 2
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Main text content
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(blocks) { block in
                        Text(block.text)
                            .font(block.isHeading
                                ? .system(size: fontSize + 4, weight: .bold)
                                : .system(size: fontSize, weight: .regular))
                            .italic(block.isItalic)
                            .padding(.bottom, block.isHeading ? 4 : 0)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.disabled)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 80) // Space for font control bar
            }
            
            // Font size control bar
            HStack(spacing: 20) {
                Button {
                    decreaseFontSize()
                } label: {
                    HStack(spacing: 4) {
                        Text("A")
                            .font(.system(size: 14, weight: .semibold))
                        Image(systemName: "minus")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(fontSize <= minFontSize ? .secondary : .primary)
                    .frame(width: 44, height: 44)
                }
                .disabled(fontSize <= minFontSize)
                
                Divider()
                    .frame(height: 24)
                
                Text("\(Int(fontSize))")
                    .font(.system(size: 16, weight: .medium))
                    .frame(minWidth: 30)
                
                Divider()
                    .frame(height: 24)
                
                Button {
                    increaseFontSize()
                } label: {
                    HStack(spacing: 4) {
                        Text("A")
                            .font(.system(size: 18, weight: .semibold))
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(fontSize >= maxFontSize ? .secondary : .primary)
                    .frame(width: 44, height: 44)
                }
                .disabled(fontSize >= maxFontSize)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            .padding(.bottom, 20)
        }
        .onAppear {
            if blocks.isEmpty {
                blocks = extractBlocks(from: pdfDocument)
            }
        }
    }
    
    // MARK: - Font Size Control
    
    private func decreaseFontSize() {
        withAnimation(.easeInOut(duration: 0.2)) {
            fontSize = max(minFontSize, fontSize - fontStep)
        }
        
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
    
    private func increaseFontSize() {
        withAnimation(.easeInOut(duration: 0.2)) {
            fontSize = min(maxFontSize, fontSize + fontStep)
        }
        
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
    
    // MARK: - Text Extraction
    
    /// Extract text blocks with formatting metadata from all pages of the PDF document
    private func extractBlocks(from document: PDFDocument) -> [TextBlock] {
        var allBlocks: [TextBlock] = []

        for i in 0..<document.pageCount {
            guard let page = document.page(at: i),
                  let attributed = page.attributedString,
                  attributed.length > 0
            else { continue }

            // Step 1: compute dominant body style for this page
            let bodyStyle = dominantBodyStyle(from: attributed)

            // Step 2: split into lines, evaluate each line as a whole
            let fullText = attributed.string
            let lineRanges = fullText.components(separatedBy: "\n")
                .reduce(into: [(NSRange, String)]()) { result, line in
                    let start = result.last.map {
                        $0.0.location + $0.0.length + 1
                    } ?? 0
                    let nsRange = NSRange(location: start, length: line.utf16.count)
                    result.append((nsRange, line))
                }

            // Step 3: get page bounds for header/footer exclusion
            let pageBounds = page.bounds(for: .mediaBox)
            let headerThreshold = pageBounds.height * 0.90
            let footerThreshold = pageBounds.height * 0.10

            var current = ""
            var currentIsHeading = false
            var currentIsItalic = false

            for (nsRange, lineText) in lineRanges {
                let trimmed = lineText.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else {
                    // Empty line = paragraph break, flush current
                    if !current.isEmpty {
                        allBlocks.append(TextBlock(
                            text: current,
                            isHeading: currentIsHeading,
                            isItalic: currentIsItalic
                        ))
                        current = ""
                    }
                    continue
                }

                // Step 4: check position — skip header/footer
                if let selection = page.selection(for: nsRange) {
                    let bounds = selection.bounds(for: page)
                    if bounds != .zero {
                        let midY = bounds.midY
                        if midY > headerThreshold || midY < footerThreshold { continue }
                    }
                }

                // Step 5: evaluate line style from its attributed range
                guard nsRange.location + nsRange.length <= attributed.length else { continue }
                var maxSize: CGFloat = 0
                var boldChars = 0
                var italicChars = 0
                var totalChars = 0

                attributed.enumerateAttributes(
                    in: nsRange,
                    options: []
                ) { attrs, _, _ in
                    let font = attrs[.font] as? UIFont ?? UIFont.systemFont(ofSize: 12)
                    let name = font.fontName.lowercased()
                    let size = font.pointSize
                    let count = trimmed.count  // approximate
                    maxSize = max(maxSize, size)
                    if name.contains("bold") || name.contains("heavy") ||
                       name.contains("black") || name.contains("semibold") {
                        boldChars += count
                    }
                    if name.contains("italic") || name.contains("oblique") {
                        italicChars += count
                    }
                    totalChars += count
                }

                guard totalChars > 0 else { continue }
                let lineMostlyBold = Double(boldChars) / Double(totalChars) > 0.6
                let lineMostlyItalic = Double(italicChars) / Double(totalChars) > 0.6
                let isLarger = maxSize > bodyStyle.fontSize + 1.5
                let isHeavierThanBody = lineMostlyBold && !bodyStyle.isBold
                let isHeading = isLarger || isHeavierThanBody

                // Step 6: join or flush
                if current.isEmpty {
                    current = trimmed
                    currentIsHeading = isHeading
                    currentIsItalic = lineMostlyItalic
                } else if isHeading != currentIsHeading || lineMostlyItalic != currentIsItalic {
                    // Style changed — flush and start new block
                    allBlocks.append(TextBlock(
                        text: current,
                        isHeading: currentIsHeading,
                        isItalic: currentIsItalic
                    ))
                    current = trimmed
                    currentIsHeading = isHeading
                    currentIsItalic = lineMostlyItalic
                } else {
                    // Same style and sentence not ended — join
                    let lastChar = current.last
                    let sentenceEnded = lastChar == "." || lastChar == "!" ||
                                        lastChar == "?" || lastChar == ":"
                    if sentenceEnded {
                        allBlocks.append(TextBlock(
                            text: current,
                            isHeading: currentIsHeading,
                            isItalic: currentIsItalic
                        ))
                        current = trimmed
                    } else {
                        current += " " + trimmed
                    }
                }
            }

            if !current.isEmpty {
                allBlocks.append(TextBlock(
                    text: current,
                    isHeading: currentIsHeading,
                    isItalic: currentIsItalic
                ))
            }
        }
        return allBlocks
    }
    
    /// Style information for the dominant body text on a page
    struct BodyStyle {
        let fontSize: CGFloat
        let isBold: Bool
    }
    
    /// Compute the dominant body style (size + weight) for a page by finding the style that accounts for the most characters
    private func dominantBodyStyle(from attributed: NSAttributedString) -> BodyStyle {
        var styleCounts: [String: (count: Int, size: CGFloat, bold: Bool)] = [:]
        attributed.enumerateAttributes(
            in: NSRange(location: 0, length: attributed.length),
            options: []
        ) { attrs, range, _ in
            let font = attrs[.font] as? UIFont ?? UIFont.systemFont(ofSize: 12)
            let size = (font.pointSize * 2).rounded() / 2
            let name = font.fontName.lowercased()
            let bold = name.contains("bold") || name.contains("heavy") ||
                       name.contains("black") || name.contains("semibold")
            let key = "\(size)-\(bold)"
            let charCount = range.length
            if let existing = styleCounts[key] {
                styleCounts[key] = (existing.count + charCount, size, bold)
            } else {
                styleCounts[key] = (charCount, size, bold)
            }
        }
        let dominant = styleCounts.max(by: { $0.value.count < $1.value.count })?.value
        return BodyStyle(fontSize: dominant?.size ?? 12, isBold: dominant?.bold ?? false)
    }
}

// MARK: - Preview

#Preview {
    // Create a sample PDF document for preview
    if let url = Bundle.main.url(forResource: "SamplePattern", withExtension: "pdf"),
       let pdfDoc = PDFDocument(url: url) {
        TextReaderView(pdfDocument: pdfDoc)
    } else {
        Text("No preview available")
    }
}
