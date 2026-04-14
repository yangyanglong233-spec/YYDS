# Marker Overlay Migration Summary

## Overview
Migrated marker rendering from PDFAnnotation-based system to a transparent UIView overlay that sits as a sibling of the PDFView.

## Changes Made

### 1. NativePDFKitView (UIViewRepresentable)

#### makeUIView Changes
- **Before:** Returned `PDFView` directly
- **After:** Returns `UIView` container with:
  - `PDFView` as first child (with Auto Layout constraints)
  - `overlayView` (transparent UIView) as second child, positioned above PDFView
  - Both views are siblings in the container, not parent-child

#### updateUIView Changes
- **Before:** Received `PDFView` as parameter
- **After:** Receives `UIView` (container) as parameter
- Now calls `layoutMarkers()` with current page's markers on every update

### 2. Coordinator Class

#### New Properties
- `weak var overlayView: UIView?` - Reference to the overlay view
- `private var markerHostingControllers: [UIHostingController<CounterMarkerView>]` - Stores hosting controllers for markers
- `private var scrollObservation: NSKeyValueObservation?` - KVO for scroll offset changes

#### Removed Properties
- `private var currentMarkerAnnotations: [MarkerAnnotation]` - No longer needed

#### New Methods

**`setupScrollObserver()`**
- Sets up KVO observation on PDFView's scrollView.contentOffset
- Triggers `layoutMarkers()` whenever content offset changes

**`layoutMarkers(_ markers: [Marker])`**
- Removes all existing marker hosting controllers from overlay
- For each marker:
  1. Converts normalized position (0-1) to PDF page coordinates
  2. Converts PDF coordinates to screen coordinates using `pdfView.convert(_:from:)`
  3. Converts to overlay coordinate space
  4. Creates `UIHostingController` wrapping `CounterMarkerView`
  5. Adds to `overlayView`
- Maintains array of hosting controllers for cleanup

#### Modified Methods

**`handleTap(_:)`**
- Removed marker annotation tap detection
- Only handles term highlight taps now

**`pdfView(_:didClick:)`**
- Removed marker annotation handling
- Only handles term highlight annotations

#### Removed Methods
- `addMarkers(page:)` - No longer creates PDF annotations
- `removeMarkers()` - No longer needed

### 3. Notification Observers

**PDFViewPageChanged:**
- Now calls `layoutMarkers()` instead of `addMarkers()`
- Filters markers by current page index

**PDFViewScaleChanged:**
- Now calls `layoutMarkers()` after scale change
- Ensures markers reposition correctly when zooming

### 4. CounterMarkerView Changes

#### New Protocol
```swift
protocol GeometryContainer {
    var size: CGSize { get }
}

extension GeometryProxy: GeometryContainer {}
```

#### Modified Property
- **Before:** `let geometry: GeometryProxy`
- **After:** `let geometry: any GeometryContainer`

This allows the view to work with both SwiftUI's `GeometryProxy` and our custom `GeometryProxyWrapper`.

### 5. New Helper Types

**GeometryProxyWrapper**
```swift
struct GeometryProxyWrapper: GeometryContainer {
    let size: CGSize
}
```
- Mimics SwiftUI's GeometryProxy for UIKit usage
- Conforms to `GeometryContainer` protocol

## Benefits of This Approach

1. **Better Gesture Handling:** Markers are now SwiftUI views with full gesture support
2. **Easier Dragging:** Can add drag gestures directly to CounterMarkerView
3. **Consistent Rendering:** Uses the same CounterMarkerView for both image and PDF documents
4. **No Coordinate System Confusion:** Explicit coordinate conversions at layout time
5. **Reactive Updates:** Markers automatically reposition on scroll, zoom, or page change

## Removed But Not Deleted

The following classes remain in the codebase but are no longer used:
- `MarkerAnnotation` (in NativePDFReaderView.swift)
- Can be deleted in a future cleanup if no longer needed

## Testing Checklist

- [ ] Markers appear at correct positions on PDF pages
- [ ] Markers reposition correctly when zooming in/out
- [ ] Markers reposition correctly when scrolling
- [ ] Markers update when switching pages
- [ ] Tapping markers still opens the counter popup
- [ ] Adding new markers from toolbar works
- [ ] Existing markers load correctly from SwiftData
- [ ] Multiple markers on same page render correctly
- [ ] Markers don't appear on wrong pages
