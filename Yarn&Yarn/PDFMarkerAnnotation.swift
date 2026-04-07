//
//  PDFMarkerAnnotation.swift
//  Yarn&Yarn
//
//  Created by Yangyang Long on 3/18/26.
//

import PDFKit
import SwiftUI

/// Custom PDF annotation for counter markers
class PDFCounterAnnotation: PDFAnnotation {
    var markerID: UUID
    var counterLabel: String
    var currentCount: Int
    var targetCount: Int
    var markerColor: String
    
    init(
        bounds: CGRect,
        markerID: UUID,
        label: String,
        currentCount: Int,
        targetCount: Int,
        color: String
    ) {
        self.markerID = markerID
        self.counterLabel = label
        self.currentCount = currentCount
        self.targetCount = targetCount
        self.markerColor = color
        
        super.init(bounds: bounds, forType: .circle, withProperties: nil)
        
        // Configure annotation appearance - use solid color for visibility
        self.color = colorFromString(color)
        self.interiorColor = colorFromString(color).withAlphaComponent(0.8)
        self.shouldDisplay = true
        self.shouldPrint = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
    
    override func draw(with box: PDFDisplayBox, in context: CGContext) {
        // Draw native circle first
        super.draw(with: box, in: context)
        
        // Add custom badge overlay
        context.saveGState()
        
        let bounds = self.bounds
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1.0, y: -1.0)
        
        UIGraphicsPushContext(context)
        
        let rect = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height)
        
        // Draw count badge if there's progress
        if currentCount > 0 || isCompleted {
            let badgeText = "\(currentCount)"
            let badgeSize = min(bounds.width * 0.6, 24.0)
            
            let badgeRect = CGRect(
                x: (rect.width - badgeSize) / 2,
                y: (rect.height - badgeSize) / 2,
                width: badgeSize,
                height: badgeSize
            )
            
            // Badge background (white circle)
            let badgePath = UIBezierPath(ovalIn: badgeRect)
            UIColor.white.setFill()
            badgePath.fill()
            
            // Badge text
            let badgeTextAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: badgeSize * 0.6),
                .foregroundColor: isCompleted ? UIColor.systemGreen : colorFromString(markerColor),
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.alignment = .center
                    return style
                }()
            ]
            
            let textRect = CGRect(
                x: badgeRect.minX,
                y: badgeRect.minY + (badgeSize - badgeSize * 0.6) / 2,
                width: badgeSize,
                height: badgeSize * 0.6
            )
            badgeText.draw(in: textRect, withAttributes: badgeTextAttributes)
        }
        
        UIGraphicsPopContext()
        context.restoreGState()
    }
    
    private var isCompleted: Bool {
        currentCount >= targetCount
    }
    
    private func colorFromString(_ colorString: String) -> UIColor {
        switch colorString {
        case "blue": return .systemBlue
        case "green": return .systemGreen
        case "red": return .systemRed
        case "yellow": return .systemOrange
        case "purple": return .systemPurple
        default: return .systemBlue
        }
    }
}

/// Custom PDF annotation for note markers
class PDFNoteAnnotation: PDFAnnotation {
    var markerID: UUID
    var noteText: String
    var markerColor: String
    
    init(
        bounds: CGRect,
        markerID: UUID,
        note: String,
        color: String
    ) {
        self.markerID = markerID
        self.noteText = note
        self.markerColor = color
        
        super.init(bounds: bounds, forType: .circle, withProperties: nil)
        
        self.color = colorFromString(color)
        self.interiorColor = colorFromString(color).withAlphaComponent(0.8)
        self.shouldDisplay = true
        self.shouldPrint = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
    
    override func draw(with box: PDFDisplayBox, in context: CGContext) {
        // Draw native circle first
        super.draw(with: box, in: context)
        
        // Add custom icon overlay
        context.saveGState()
        
        let bounds = self.bounds
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1.0, y: -1.0)
        
        UIGraphicsPushContext(context)
        
        let rect = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height)
        
        // Draw emoji icon in center
        let iconAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: bounds.height * 0.5),
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.alignment = .center
                return style
            }()
        ]
        
        let icon = "📝"
        let iconRect = CGRect(x: 0, y: rect.height * 0.25, width: rect.width, height: rect.height * 0.5)
        icon.draw(in: iconRect, withAttributes: iconAttributes)
        
        UIGraphicsPopContext()
        context.restoreGState()
    }
    
    private func colorFromString(_ colorString: String) -> UIColor {
        switch colorString {
        case "blue": return .systemBlue
        case "green": return .systemGreen
        case "red": return .systemRed
        case "yellow": return .systemYellow
        case "purple": return .systemPurple
        default: return .systemBlue
        }
    }
}
