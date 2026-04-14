//
//  HighlightPathRenderer.swift
//  Yarn&Yarn
//
//  Created by Yangyang Long on 3/24/26.
//

import UIKit

/// Renders decorative underline paths for highlight markers
enum HighlightPathRenderer {
    
    /// Generates a yarn loop pattern (prolate cycloid) path
    /// - Parameters:
    ///   - width: The total width of the path
    ///   - scale: Scale factor relative to reference line height
    /// - Returns: A UIBezierPath representing the yarn loop pattern
    static func yarnLoopPath(width: CGFloat, scale: CGFloat) -> UIBezierPath {
        // Constants
        let loopHeight: CGFloat = 1.5 * scale
        let loopWidth: CGFloat = 6 * scale
        let overlapFactor: CGFloat = 0.32
        
        // Derived values
        let loopCount = max(1, round(width / loopWidth))
        let totalT = loopCount * 2 * .pi
        let xAdv = width / totalT
        let xRadius = xAdv + overlapFactor * loopWidth * 0.5
        let yRadius = loopHeight
        
        // Sample at Int(width * 3) steps
        let steps = Int(width * 3)
        let path = UIBezierPath()
        
        for i in 0...steps {
            let t = totalT * CGFloat(i) / CGFloat(steps)
            
            // Prolate cycloid: x(t) = xAdv*t - xRadius*sin(t), y(t) = yRadius*(1 - cos(t))
            let x = xAdv * t - xRadius * sin(t)
            let y = -yRadius * (1 - cos(t))
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        return path
    }
    
    /// Generates a scallop pattern (sine wave) path
    /// - Parameters:
    ///   - width: The total width of the path
    ///   - scale: Scale factor relative to reference line height
    /// - Returns: A UIBezierPath representing the scallop pattern
    static func scallopPath(width: CGFloat, scale: CGFloat) -> UIBezierPath {
        // Constants
        let amplitude: CGFloat = 4 * scale
        let period: CGFloat = 20 * scale
        
        // Sample at Int(width * 2) steps
        let steps = Int(width * 2)
        let path = UIBezierPath()
        
        for i in 0...steps {
            let x = width * CGFloat(i) / CGFloat(steps)
            
            // Sine wave: y(x) = amplitude * sin((x / period) * 2π)
            let y = amplitude * sin((x / period) * 2 * .pi)
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        return path
    }
}
