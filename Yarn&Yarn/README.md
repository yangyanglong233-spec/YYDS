# Yarn & Yarn - Knitting & Crocheting Pattern Assistant

A SwiftUI app for viewing knitting and crocheting instruction documents with automatic terminology highlighting and customizable markers.

## Features

### 📄 Document Management
- Import PDF and image files containing knitting/crocheting patterns
- Documents are stored locally using SwiftData
- List view shows all imported patterns with metadata

### 🔍 Terminology Highlighting
- Automatically detects and highlights knitting terminology (starting with "K")
- Uses Vision framework for OCR text recognition
- Tap any highlighted term to see its definition
- Extensible terminology dictionary with common abbreviations:
  - K (Knit)
  - P (Purl)
  - YO (Yarn Over)
  - K2TOG (Knit Two Together)
  - SSK (Slip, Slip, Knit)
  - And more...

### 📍 Marker System
- Add markers/notes anywhere on your pattern
- Drag and drop markers to reposition them
- Tap markers to edit notes
- Color-coded markers (blue, green, red, yellow, purple)
- Markers are saved with the document

### 📱 Document Viewing
- **PDF Support**: View multi-page PDF documents with pinch-to-zoom
- **Image Support**: Display pattern images with gesture controls
- **Zoom & Pan**: Magnification gestures for detailed viewing

## Architecture

### Models (SwiftData)
- **InstructionDocument**: Stores PDF/image data, metadata, and relationships
- **Marker**: Stores user notes with position and styling information

### Views
- **ContentView**: Main list of all imported patterns
- **DocumentImportView**: Import interface for PDFs and images
- **DocumentViewerView**: Main viewer with overlay system
- **TextHighlightingView**: Vision-based text detection and highlighting
- **MarkerView**: Draggable, tappable marker components

### Key Technologies
- **SwiftUI**: Modern declarative UI
- **SwiftData**: Data persistence and relationships
- **PDFKit**: PDF rendering
- **Vision Framework**: Text recognition (OCR)
- **PhotosPicker**: Image import
- **FileImporter**: PDF document import

## Usage

1. **Import a Pattern**
   - Tap the "+" button
   - Choose to import a PDF or image
   - Give your pattern a name

2. **View Pattern**
   - Tap any pattern in the list
   - Capital "K" terms are automatically highlighted in yellow
   - Tap highlighted terms for definitions

3. **Add Markers**
   - Use the floating marker palette on the right
   - Tap the menu button to add a marker at center
   - Drag markers to reposition
   - Tap markers to edit notes and change colors

4. **Manage Patterns**
   - Swipe to delete patterns
   - Use Edit button for bulk operations

## Future Enhancements

- [ ] Support for more knitting terminology (P, YO, K2TOG, etc.)
- [ ] Enhanced drag-and-drop from palette to document
- [ ] Row counter integration
- [ ] Pattern search and filtering
- [ ] Export annotations as separate file
- [ ] Sharing patterns with annotations
- [ ] Dark mode optimization
- [ ] iPad split-view support
- [ ] Widget for quick pattern access

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Notes

The app currently focuses on highlighting capital "K" as a proof of concept. The `KnittingTerminology` dictionary in `TextHighlightingView.swift` can be easily extended to support more abbreviations. The Vision framework detection can be enhanced to recognize more pattern-specific terminology.
