//
//  Marker.swift
//  Yarn&Yarn
//
//  Created by Yangyang Long on 3/16/26.
//

import Foundation
import SwiftData
import CoreGraphics

@Model
final class Marker {
    enum MarkerType: String, Codable {
        case note = "note"
        case counter = "counter"
        case highlight = "highlight"
    }
    
    enum HighlightStyle: String, Codable {
        case yarnLoop   // Basic Stitches — purple
        case scallop    // Texture Techniques — coral
    }
    
    var id: UUID
    var type: MarkerType
    
    // Common properties
    var positionX: Double // Position on the document (0-1 normalized)
    var positionY: Double
    var pageNumber: Int // For PDFs with multiple pages
    var createdDate: Date
    var color: String // Color name for the tag
    
    // Highlight-specific properties
    var rectX: Double?
    var rectY: Double?
    var rectWidth: Double?
    var rectHeight: Double?
    var highlightStyle: HighlightStyle?
    
    // Computed property to reconstruct CGRect from individual components
    var pageRect: CGRect? {
        guard let x = rectX, let y = rectY, let w = rectWidth, let h = rectHeight else {
            return nil
        }
        return CGRect(x: x, y: y, width: w, height: h)
    }
    
    // Note-specific properties
    var note: String
    
    // Counter-specific properties
    var counterLabel: String
    var currentCount: Int
    var targetCount: Int
    
    // Relationship
    var document: InstructionDocument?
    
    // Computed properties
    var isCompleted: Bool {
        type == .counter && currentCount >= targetCount
    }
    
    var progress: Double {
        guard type == .counter, targetCount > 0 else { return 0 }
        return Double(currentCount) / Double(targetCount)
    }
    
    // MARK: - Initializers
    
    init(
        type: MarkerType,
        note: String = "",
        counterLabel: String = "",
        currentCount: Int = 0,
        targetCount: Int = 1,
        positionX: Double,
        positionY: Double,
        pageNumber: Int = 0,
        color: String = "blue"
    ) {
        self.id = UUID()
        self.type = type
        self.note = note
        self.counterLabel = counterLabel
        self.currentCount = currentCount
        self.targetCount = targetCount
        self.positionX = positionX
        self.positionY = positionY
        self.pageNumber = pageNumber
        self.createdDate = Date()
        self.color = color
    }
    
    // MARK: - Convenience Factory Methods
    
    static func noteMarker(
        note: String = "",
        positionX: Double,
        positionY: Double,
        pageNumber: Int = 0,
        color: String = "blue"
    ) -> Marker {
        Marker(
            type: .note,
            note: note,
            positionX: positionX,
            positionY: positionY,
            pageNumber: pageNumber,
            color: color
        )
    }
    
    static func counterMarker(
        label: String = "Repeat",
        targetCount: Int = 6,
        positionX: Double,
        positionY: Double,
        pageNumber: Int = 0,
        color: String = "blue"
    ) -> Marker {
        Marker(
            type: .counter,
            counterLabel: label,
            currentCount: 0,
            targetCount: targetCount,
            positionX: positionX,
            positionY: positionY,
            pageNumber: pageNumber,
            color: color
        )
    }
    
    // MARK: - Counter Actions
    
    func increment() {
        guard type == .counter else { return }
        currentCount += 1
    }
    
    func decrement() {
        guard type == .counter else { return }
        currentCount = max(0, currentCount - 1)
    }
    
    func reset() {
        guard type == .counter else { return }
        currentCount = 0
    }
}
