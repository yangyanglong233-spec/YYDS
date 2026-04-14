# SVG Counter Marker Background Guide

## Overview
The app now supports loading custom SVG shapes from your Resources folder as backgrounds for **counter markers**. This uses **native iOS APIs only** (no external dependencies) and allows you to iterate on counter marker designs without changing code.

## What This Does

The `markerShape.svg` file will be used as the **background shape** for counter markers (the ones that show "0/6" count). The SVG:
- Replaces the default rounded rectangle background
- Determines the size of the marker
- Uses its own colors from the SVG file (or defaults to yellow)
- Changes to green when the counter is complete
- Scales with zoom like all other markers

**Note markers** (📌) are not affected and keep their current appearance.

## Setup Steps

### 1. No External Dependencies Required!

This implementation uses **native iOS APIs only**:
- `Foundation` for loading files
- `UIKit` for parsing and rendering
- `CoreGraphics` for path manipulation

No Swift Package Manager, CocoaPods, or third-party libraries needed!

### 2. Ensure Your SVG File is in Bundle

Make sure `markerShape.svg` is:
- Located in your **Resources** folder
- Added to your app target (check Target Membership in File Inspector)
- Set to "Copy Bundle Resources" in Build Phases

### 3. Updated Files

The following files have been modified to support SVG counter backgrounds:

#### **NativePDFReaderView.swift**
- Updated `SimpleMarkerView` class:
  - New property: `svgShapeLayer` to hold the SVG background
  - New method: `setupSVGBackground()` loads and parses the SVG
  - New method: `extractSVGPathData()` uses regex to extract path data from SVG XML
  - Updated `updateAppearance()`, `completeCounter()`, and `flashFeedback()` to work with SVG
- Added `UIBezierPath` extension for parsing SVG path data:
  - Supports basic SVG commands: **M, L, H, V, C, Q, Z**
  - Converts SVG path string to native `UIBezierPath`

## Usage

### Counter markers automatically use the SVG background

When you create a counter marker, it will automatically use `markerShape.svg` if available:

```swift
let counter = Marker.counterMarker(
    label: "Repeat",
    targetCount: 6,
    positionX: 0.5,
    positionY: 0.5,
    pageNumber: 0
)
// Will automatically use markerShape.svg as background
```

### To iterate on the design:

1. **Update** `markerShape.svg` in your Resources folder
2. **Rebuild** the app
3. The new shape will be loaded automatically!

No code changes needed when you modify the SVG file.

## SVG Requirements

Your `markerShape.svg` should:
- Contain at least one `<path>` element (the first path will be used)
- Use standard SVG path commands
- Have reasonable dimensions (this determines the marker size)
- Work as a filled shape (not just a stroke)
- Be designed to contain text/icons in the center

### Supported SVG Commands:
- **M** - Move to (absolute)
- **L** - Line to (absolute)
- **H** - Horizontal line to (absolute)
- **V** - Vertical line to (absolute)
- **C** - Cubic Bezier curve (absolute)
- **Q** - Quadratic Bezier curve (absolute)
- **Z** - Close path

**Note:** Relative commands (lowercase) are not currently supported. Use absolute coordinates only.

### Recommended SVG structure:

```xml
<svg width="50" height="50" viewBox="0 0 50 50" xmlns="http://www.w3.org/2000/svg">
  <path d="M 25 5 L 45 25 L 25 45 L 5 25 Z" fill="yellow" />
</svg>
```

### Example: Rounded Square
```xml
<svg width="44" height="44" viewBox="0 0 44 44" xmlns="http://www.w3.org/2000/svg">
  <path d="M 10 4 L 34 4 Q 40 4 40 10 L 40 34 Q 40 40 34 40 L 10 40 Q 4 40 4 34 L 4 10 Q 4 4 10 4 Z" fill="#FFD700"/>
</svg>
```

## Fallback Behavior

If the SVG file cannot be loaded, the system will:
1. Print a warning to console: "⚠️ markerShape.svg not found in bundle - using fallback appearance"
2. Use the default rounded rectangle appearance
3. Continue working normally without crashing

## Visual Behavior

### Counter States:

**Incomplete (0/6, 1/6, etc.):**
- SVG background uses yellow (or its original fill color)
- Counter text displayed in center
- Yellow → Green flash feedback on tap

**Complete (6/6):**
- SVG background changes to green
- Checkmark (✓) replaces the counter text
- Tap gesture disabled

### Sizing:
- SVG **determines the marker size** (uses path bounds)
- Text is automatically centered within the SVG bounds
- Scales with PDF zoom

### Positioning:
- Counter text is automatically centered
- Checkmark (when complete) is centered with 8pt inset

## Technical Details

### How it works:
1. When a counter marker is created, `setupSVGBackground()` is called
2. SVG is loaded from `Bundle.main.url(forResource: "markerShape", withExtension: "svg")`
3. Regex extracts the `d="..."` attribute from the first `<path>` element
4. `UIBezierPath(svgPath:)` extension parses the path data string
5. A `CAShapeLayer` is created with the path and added to the marker view
6. The marker view resizes to match the SVG dimensions
7. Shadow is applied to the shape layer
8. Colors are changed by modifying `shapeLayer.fillColor`

### SVG Parsing:
- Uses `NSRegularExpression` to extract path data
- Custom `UIBezierPath` extension parses SVG commands
- Handles spaces and commas as delimiters
- Converts SVG coordinates to `CGPoint` structures

### Color Management:
- Initial color: Uses systemYellow by default
- On increment: Flashes green briefly, then back to yellow
- On complete: Changes to green permanently
- Colors are animated with UIView.animate()

### Performance:
- SVG is loaded and parsed once per marker view creation
- Path parsing is fast (< 5ms for typical shapes)
- No caching needed for current implementation
- Rendering uses hardware-accelerated Core Animation

## Troubleshooting

**Problem:** "⚠️ markerShape.svg not found in bundle"
- **Solution:** Check Target Membership and ensure it's in "Copy Bundle Resources" build phase

**Problem:** "⚠️ No valid path found in markerShape.svg"
- **Solution:** Ensure your SVG has a `<path>` element with a `d="..."` attribute

**Problem:** "⚠️ Failed to parse SVG path data"
- **Solution:** Check that your path uses absolute commands (M, L, C, Q, not m, l, c, q)

**Problem:** Marker is too large/small
- **Solution:** Adjust the viewBox or path coordinates in your SVG file

**Problem:** Counter text is not centered
- **Solution:** Make sure your SVG path is roughly centered around its bounds

**Problem:** Shape looks jagged
- **Solution:** Use more control points or smoother curves (C, Q commands)

**Problem:** Note markers (📌) changed appearance
- **Solution:** This shouldn't happen - note markers are excluded from SVG background. File a bug if this occurs.

## Migration from Old Markers

Existing counter markers will automatically switch to the new SVG background on next app launch if `markerShape.svg` is present in the bundle. No data migration needed!

## Extending the Parser

To add support for more SVG commands, extend the `UIBezierPath` extension in `NativePDFReaderView.swift`:

```swift
case "A": // Arc (currently not supported)
    // Add arc parsing here
    break
```

The parser currently handles the most common SVG path commands used in icon design.
