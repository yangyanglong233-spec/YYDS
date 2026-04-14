# View Hierarchy - Before and After

## Before: PDFAnnotation-Based System

```
NativePDFKitView (UIViewRepresentable)
└── PDFView
    ├── [PDF Content]
    ├── TermHighlightAnnotation (subclass of PDFAnnotation)
    └── MarkerAnnotation (subclass of PDFAnnotation) ❌
        - Gestures unreliable
        - Hard to drag
        - Coordinate system issues
```

## After: UIView Overlay System

```
NativePDFKitView (UIViewRepresentable)
└── UIView (Container) ✅
    ├── PDFView (Constrained to fill container)
    │   ├── [PDF Content]
    │   └── TermHighlightAnnotation (still using PDFAnnotation)
    │
    └── UIView (overlayView) ✅ NEW
        ├── backgroundColor = .clear
        ├── isUserInteractionEnabled = true
        └── Contains:
            ├── UIHostingController<CounterMarkerView> #1
            ├── UIHostingController<CounterMarkerView> #2
            └── UIHostingController<CounterMarkerView> #3
                - Full SwiftUI gesture support ✅
                - Easy dragging ✅
                - Consistent with image viewer ✅
```

## Coordinate Conversion Flow

```
1. Marker Model (SwiftData)
   ├── positionX: Double (0.0 - 1.0, normalized)
   └── positionY: Double (0.0 - 1.0, normalized)
   
2. Convert to PDF Page Coordinates
   ├── x = positionX * pageBounds.width
   └── y = positionY * pageBounds.height
   
3. Convert to PDFView Screen Coordinates
   └── pointInPDFView = pdfView.convert(pointInPage, from: page)
   
4. Convert to Overlay Coordinates
   ├── pointInContainer = pdfView.convert(pointInPDFView, to: containerView)
   └── pointInOverlay = overlayView.convert(pointInContainer, from: containerView)
   
5. Position UIHostingController
   └── Set frame with full overlay size
       (CounterMarkerView uses .position() to center itself)
```

## Automatic Updates Triggered By:

### PDFViewPageChanged Notification
```
User swipes to new page
└→ Coordinator.updateCurrentPage(newIndex)
   └→ layoutMarkers(markersForPage)
      └→ Remove old hosting controllers
      └→ Add new hosting controllers for new page
```

### PDFViewScaleChanged Notification
```
User pinches to zoom
└→ Coordinator.updateScale(newScale)
   └→ layoutMarkers(markersForCurrentPage)
      └→ Recalculate screen positions
      └→ Update hosting controller positions
```

### ScrollView contentOffset KVO
```
User scrolls/pans PDF
└→ scrollView.contentOffset changes
   └→ layoutMarkers(markersForCurrentPage)
      └→ Markers track with content
```

### updateUIView Called
```
SwiftUI state changes (e.g., marker added/removed)
└→ updateUIView(_:context:)
   └→ layoutMarkers(markersForCurrentPage)
      └→ Sync overlay with current model state
```

## Key Design Decisions

### Why Siblings Instead of Parent-Child?
- PDFView has complex internal gesture recognizers
- Adding subview to PDFView caused gesture conflicts
- Siblings can have independent gesture handling
- Easier to position overlay to exactly match PDFView bounds

### Why UIHostingController?
- Reuses existing CounterMarkerView SwiftUI code
- Maintains consistency with image viewer
- Access to SwiftUI gesture modifiers
- Easy to extend with animations

### Why Not Just Update PDFAnnotation Subclass?
- PDFAnnotation gesture handling is limited
- Can't use SwiftUI drag gestures
- Coordinate system conversions are complex
- Annotation rendering happens in PDF coordinate space
- Hard to sync with SwiftUI state changes

### Why Keep TermHighlightAnnotation as PDFAnnotation?
- Term highlights don't need dragging
- They're tied to actual text in the PDF
- They scroll naturally with PDF content
- No need to migrate unless required
