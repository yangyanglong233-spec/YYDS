# Native PDF Reader Architecture

## Component Hierarchy

```
DocumentViewerView
│
├─ if document.isPDF:
│  └─ NativePDFDocumentView
│     └─ NativePDFReaderView
│        ├─ ScrollView (vertical + horizontal)
│        │  └─ VStack (pages)
│        │     └─ ForEach page in pdfDocument
│        │        └─ NativePDFPageView
│        │           ├─ Image (rendered PDF page)
│        │           ├─ Terminology Highlights (if enabled)
│        │           │  └─ Rectangle overlays (tappable)
│        │           └─ Markers for this page
│        │              └─ NativePDFMarkerView (draggable)
│        │
│        ├─ MagnifyGesture (zoom)
│        │
│        └─ Sheets:
│           ├─ GlossaryTermDetailView (term tapped)
│           └─ CounterPopupView / MarkerNoteEditorView (marker tapped)
│
└─ MarkerPaletteView (floating top-right)
   ├─ Counter Button
   └─ Note Button
```

## Data Flow

### Rendering Pipeline

```
PDFDocument
    ↓
PDFPage.draw(with:to:)
    ↓
UIGraphicsImageRenderer
    ↓
UIImage (cached)
    ↓
SwiftUI Image View
```

### Terminology Highlighting Pipeline

```
User toggles "Highlight Terms" ON
    ↓
NativePDFPageView.findTerminologyInPage()
    ↓
PDFPage.string → full page text
    ↓
KnittingGlossary.findTerms(in: pageText)
    ↓
For each found term:
    PDFPage.selection(for: NSRange)
        ↓
    selection.bounds(for: page)
        ↓
    Transform to view coordinates
        ↓
    Create TermHighlight model
        ↓
    Display Rectangle overlay
```

### Marker Interaction Pipeline

```
User drags marker:
    ↓
DragGesture
    ↓
Update visual position (using @GestureState)
    ↓
On drag end:
    Calculate normalized position (0-1)
        ↓
    Update Marker.positionX, positionY
        ↓
    Save to SwiftData
        ↓
    Haptic feedback
```

## Coordinate Systems

### PDF Coordinate Space
- Origin: Bottom-left corner
- X: 0 = left, width = right
- Y: 0 = bottom, height = top

### SwiftUI View Coordinate Space
- Origin: Top-left corner
- X: 0 = left, width = right
- Y: 0 = top, height = bottom

### Normalized Marker Coordinates (Stored)
- Range: 0.0 to 1.0
- X: 0.0 = left edge, 1.0 = right edge
- Y: 0.0 = top edge, 1.0 = bottom edge
- Page-independent, resolution-independent

### Transformation Formula

```swift
// PDF bounds to View coordinates (for highlights)
let scaleX = pageSize.width / pageBounds.width
let scaleY = pageSize.height / pageBounds.height

let transformedRect = CGRect(
    x: pdfBounds.origin.x * scaleX,
    y: pageSize.height - (pdfBounds.origin.y * scaleY) - (pdfBounds.height * scaleY),
    width: pdfBounds.width * scaleX,
    height: pdfBounds.height * scaleY
)

// Normalized to View coordinates (for markers)
let position = CGPoint(
    x: marker.positionX * pageSize.width,
    y: marker.positionY * pageSize.height
)

// View to Normalized coordinates (after drag)
let normalizedX = viewPosition.x / pageSize.width
let normalizedY = viewPosition.y / pageSize.height
```

## State Management

### View State (@State)

**NativePDFReaderView:**
- `scale: CGFloat` - Current zoom level
- `lastScale: CGFloat` - Previous zoom level (for incremental zoom)
- `selectedTerm: KnittingGlossary.Term?` - Term to show in sheet
- `showingTermDetail: Bool` - Sheet presentation state
- `selectedMarker: Marker?` - Marker to show in sheet
- `showingMarkerPopup: Bool` - Sheet presentation state

**NativePDFPageView:**
- `renderedImage: UIImage?` - Cached page render
- `pageSize: CGSize` - Calculated page dimensions
- `terminologyHighlights: [TermHighlight]` - Found term locations

**NativePDFMarkerView:**
- `isDragging: Bool` - Whether marker is being dragged
- `dragOffset: CGSize` - Accumulated drag offset
- `@GestureState gestureOffset: CGSize` - Current gesture offset

### Persisted State (SwiftData)

**Marker model:**
- `positionX: Double` - Normalized X (0-1)
- `positionY: Double` - Normalized Y (0-1)
- `pageNumber: Int` - Which page marker is on
- `type: MarkerType` - Counter or Note
- `currentCount: Int` - For counter markers
- `targetCount: Int` - For counter markers
- `note: String` - For note markers
- `color: String` - Display color

## Performance Characteristics

### Rendering
- **Initial Load**: O(n) where n = page count
- **Page Render**: ~100-300ms per page at 2x scale
- **Memory**: ~2-4MB per rendered page
- **Thread**: Background (DispatchQueue.global)

### Terminology Highlighting
- **Text Extraction**: O(1) per page (native PDF operation)
- **Term Search**: O(m * k) where m = terms, k = page text length
- **Highlight Creation**: O(p) where p = found terms
- **Thread**: Background (DispatchQueue.global)

### Marker Operations
- **Rendering**: O(m) where m = markers on current page
- **Drag**: O(1) - simple coordinate transform
- **Save**: O(1) - single SwiftData update

## Multi-Page Behavior

### Current Implementation
```
Page 0: Shows markers where pageNumber == 0
Page 1: Shows markers where pageNumber == 1
Page 2: Shows markers where pageNumber == 2
...
```

### How to Add Cross-Page Dragging

```swift
// In NativePDFMarkerView, during drag gesture:
.onEnded { value in
    let finalY = (position.y + finalOffset.height) / pageSize.height
    
    // Check if dragged below page
    if finalY > 1.0 {
        marker.pageNumber += 1
        marker.positionY = finalY - 1.0 // Carry over to next page
    }
    // Check if dragged above page
    else if finalY < 0.0 && marker.pageNumber > 0 {
        marker.pageNumber -= 1
        marker.positionY = 1.0 + finalY // Carry over to previous page
    }
    else {
        marker.positionY = max(0.05, min(0.95, finalY))
    }
}
```

## Comparison: Old vs New

| Feature | PDFKitView (Old) | NativePDFReaderView (New) |
|---------|------------------|---------------------------|
| **Gesture Handling** | UIKit gestures + delegates | Pure SwiftUI gestures |
| **Marker Positioning** | PDF annotations | SwiftUI overlays |
| **Coordinate Space** | Multiple (complex) | Single normalized space |
| **Multi-Page Support** | Broken | Working |
| **Scroll Conflicts** | Yes | No |
| **Terminology** | PDF annotations | SwiftUI overlays |
| **Code Complexity** | High (400+ lines) | Medium (300 lines) |
| **Maintainability** | Difficult | Easy |
| **Extensibility** | Limited | High |
| **Performance** | Good | Good |

## Extension Points

### Easy to Add

1. **Page Navigation Sidebar**
   ```swift
   HStack {
       PageThumbnailSidebar(pages: pdfDocument.pages)
       NativePDFReaderView(...)
   }
   ```

2. **Marker Templates**
   ```swift
   // Save marker as template
   let template = MarkerTemplate(from: marker)
   
   // Apply template
   let newMarker = Marker(from: template, at: position)
   ```

3. **Marker Groups**
   ```swift
   // Add to Marker model
   var groupID: UUID?
   
   // Move all markers in group together
   ```

4. **Custom Marker Types**
   ```swift
   enum MarkerType {
       case note
       case counter
       case timer        // NEW
       case rowCounter   // NEW
       case bookmark     // NEW
   }
   ```

### Moderate Effort

1. **Text Selection**: Use Vision framework
2. **Annotation Tools**: Draw shapes on PDF
3. **Export PDF**: Embed markers as real PDF annotations
4. **Offline Sync**: CloudKit integration

### Advanced

1. **OCR Enhancement**: Re-OCR poor quality PDFs
2. **AI Pattern Analysis**: Detect pattern structure
3. **Auto-Marker Placement**: Suggest marker positions
4. **Collaborative Editing**: Real-time multi-user markers

---

This architecture provides a solid foundation for current needs while remaining flexible for future enhancements. The normalized coordinate system and clean separation of concerns make the codebase maintainable and extensible.
