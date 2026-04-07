# SVG Counter Marker Background Guide

## Overview
The app now supports loading custom SVG shapes from your Resources folder as backgrounds for **counter markers**. This allows you to iterate on counter marker designs without changing code.

## What This Does

The `markerShape.svg` file will be used as the **background shape** for counter markers (the ones that show "0/6" count). The SVG:
- Replaces the default rounded rectangle background
- Determines the size of the marker
- Uses its own colors from the SVG file
- Changes to green when the counter is complete
- Scales with zoom like all other markers

**Note markers** (📌) are not affected and keep their current appearance.

## Setup Steps

### 1. Add PocketSVG Package Dependency

**Using Swift Package Manager in Xcode:**
1. Go to **File → Add Package Dependencies**
2. Enter: `https://github.com/pocketsvg/PocketSVG`
3. Select version `2.7.0` or later
4. Add to your target

**Or add to Package.swift:**
```swift
dependencies: [
    .package(url: "https://github.com/pocketsvg/PocketSVG", from: "2.7.0")
]
```

### 2. Ensure Your SVG File is in Bundle

Make sure `markerShape.svg` is:
- Located in your **Resources** folder
- Added to your app target (check Target Membership in File Inspector)
- Set to "Copy Bundle Resources" in Build Phases

### 3. Updated Files

The following files have been modified to support SVG counter backgrounds:

#### **NativePDFReaderView.swift**
- Added `import PocketSVG`
- Updated `SimpleMarkerView` class:
  - New property: `svgShapeLayer` to hold the SVG background
  - New method: `setupSVGBackground()` loads and configures the SVG
  - Updated `updateAppearance()`, `completeCounter()`, and `flashFeedback()` to work with SVG

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
- Use standard SVG path commands (M, L, C, Q, etc.)
- Have reasonable dimensions (this determines the marker size)
- Work as a filled shape (not just a stroke)
- Be designed to contain text/icons in the center

### Recommended SVG structure:

```xml
<svg width="50" height="50" viewBox="0 0 50 50" xmlns="http://www.w3.org/2000/svg">
  <path d="M25,5 L45,25 L25,45 L5,25 Z" fill="yellow" />
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
- SVG background uses its original colors (or yellow if no fill specified)
- Counter text displayed in center
- Yellow → Green flash feedback on tap

**Complete (6/6):**
- SVG background changes to green
- Checkmark (✓) replaces the counter text
- Tap gesture disabled

### Sizing:
- SVG **determines the marker size** (uses viewBox/path bounds)
- Text is centered within the SVG bounds
- Scales with PDF zoom

### Positioning:
- Counter text is automatically centered
- Checkmark (when complete) is centered with 8pt inset

## Technical Details

### How it works:
1. When a counter marker is created, `setupSVGBackground()` is called
2. SVG is loaded from `Bundle.main.url(forResource: "markerShape", withExtension: "svg")`
3. PocketSVG parses the SVG and extracts the first path
4. A `CAShapeLayer` is created with the path and added to the marker view
5. The marker view resizes to match the SVG dimensions
6. Shadow is applied to the shape layer (not the view)
7. Colors are changed by modifying `shapeLayer.fillColor`

### Color Management:
- Initial color: Uses SVG's fill color, or defaults to yellow
- On increment: Flashes green briefly, then back to yellow
- On complete: Changes to green permanently
- Colors are animated with UIView.animate()

### Performance:
- SVG is loaded once per marker view creation
- Path generation is fast (< 1ms typically)
- No caching needed for current implementation

## Troubleshooting

**Problem:** "⚠️ markerShape.svg not found in bundle"
- **Solution:** Check Target Membership and ensure it's in "Copy Bundle Resources" build phase

**Problem:** "⚠️ No paths found in markerShape.svg"
- **Solution:** Ensure your SVG has at least one `<path>` element

**Problem:** Marker is too large/small
- **Solution:** Adjust the width/height or viewBox in your SVG file

**Problem:** Counter text is not centered
- **Solution:** Make sure your SVG path is roughly centered around its bounds
**Problem:** SVG colors don't show
- **Solution:** Check that your SVG `<path>` has a `fill` attribute

**Problem:** Note markers (📌) changed appearance
- **Solution:** This shouldn't happen - note markers are excluded from SVG background. File a bug if this occurs.

## Migration from Old Markers

Existing counter markers will automatically switch to the new SVG background on next app launch if `markerShape.svg` is present in the bundle. No data migration needed!

