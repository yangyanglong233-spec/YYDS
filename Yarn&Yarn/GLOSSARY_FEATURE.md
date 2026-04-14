# Knitting Glossary Highlighting Feature

## Overview
This implementation adds comprehensive glossary highlighting for knitting terms in the Yarn & Yarn app. The feature automatically detects and highlights knitting terminology in both PDF documents and images, allowing users to tap on highlighted terms to view definitions.

## Key Components

### 1. KnittingGlossary.swift
- **Purpose**: Central glossary database containing all knitting terms
- **Features**:
  - 100+ knitting terms organized into 14 categories
  - Each term includes: abbreviation, full name, definition, category, and aliases
  - Smart pattern matching that respects word boundaries
  - Category-based organization (Basic Stitches, Cast On, Bind Off, Increases, Decreases, Cables, Colorwork, Texture, Lace, Construction, In the Round, Finishing, Yarn & Tools, Pattern Reading)

### 2. TextHighlightingView.swift (Updated)
- **Purpose**: Handles text detection and highlighting for images
- **Features**:
  - Uses Vision framework for OCR text recognition
  - Automatically detects all glossary terms in images
  - Color-coded highlights based on term category:
    - Yellow: Basic Stitches
    - Orange: Increases/Decreases
    - Green: Cast On/Bind Off
    - Purple: Cables
    - Pink: Colorwork
    - Cyan: Lace
    - Blue: Other categories
  - Tap-to-view definitions
  - Background processing for performance

### 3. PDFTextHighlighter.swift (New)
- **Purpose**: Handles text detection and highlighting for PDFs
- **Features**:
  - Scans PDF text for knitting terms
  - Creates highlight annotations directly on PDF pages
  - Same color-coding system as image highlighting
  - Tap gesture recognition on annotations
  - Can toggle highlights on/off

### 4. GlossaryTermDetailView (New)
- **Purpose**: Beautiful detail view for individual terms
- **Features**:
  - Full term name and abbreviation
  - Category badge with color coding
  - Complete definition
  - Aliases (alternative names for the term)
  - Related terms in the same category
  - Presented as a sheet with medium/large detents

### 5. GlossaryBrowserView.swift (New)
- **Purpose**: Browse all glossary terms
- **Features**:
  - Complete A-Z list of all terms
  - Category filter buttons
  - Search functionality
  - Navigation to term details
  - Accessible from main menu and document viewer

### 6. Updates to Existing Files

#### ContentView.swift
- Added "Glossary" button in navigation bar
- Opens GlossaryBrowserView as a sheet

#### DocumentViewerView.swift
- Added toggle for highlighting on/off
- Added menu option to view glossary from document
- Passes highlighting state to PDF and Image viewers

## How It Works

### For Images:
1. When an image document is opened with highlighting enabled
2. Vision framework performs OCR on the image
3. Detected text is searched for knitting terms using the glossary
4. Matching terms are highlighted with color-coded overlays
5. Tapping a highlight shows the term definition sheet

### For PDFs:
1. When a PDF document is opened with highlighting enabled
2. PDF text is extracted from each page
3. Text is searched for knitting terms using the glossary
4. PDFAnnotation highlights are added to matching terms
5. Tapping a highlight shows the term definition sheet

### Pattern Matching:
- Case-insensitive matching
- Word boundary detection (won't match "K" in "KNITTING")
- Longest-first matching to catch multi-character abbreviations first
- Handles aliases (e.g., "sl1" and "sl" both match)

## Categories Included

1. **Basic Stitches**: k, p, k2tog, ssk, yo, sl, kfb, etc.
2. **Cast On Methods**: CO, long-tail, cable cast on, provisional, etc.
3. **Bind Off Methods**: BO, stretchy bind off, three-needle, i-cord, etc.
4. **Increases**: M1L, M1R, M1P, kfb, LLI, RLI
5. **Decreases**: k2tog, ssk, k3tog, sssk, skp, cdd
6. **Cable Techniques**: C4F, C4B, cn, rope cable, travelling stitch
7. **Colorwork**: Fair Isle, intarsia, stranded, mosaic, duplicate stitch
8. **Texture Techniques**: seed stitch, ribbing, garter, stockinette, brioche
9. **Lace**: eyelet, nupps, bobble, picot
10. **Construction & Shaping**: short rows, w&t, GSR, raglan, yoke, steek, gusset
11. **Working in the Round**: BOR, magic loop, DPN, join
12. **Finishing**: mattress stitch, Kitchener, blocking, weaving in ends
13. **Yarn & Tools**: WPI, gauge, ease, ply, skein, hank
14. **Pattern Reading**: RS, WS, rep, pm, sm, rm, st, sts

## User Experience

### Highlighting Toggle
Users can toggle highlighting on/off per document from the menu:
- Menu → "Highlight Terms" toggle
- Immediately applies/removes highlights
- Preference is per-viewing session (not persisted)

### Glossary Browser
Access from two places:
1. Main app toolbar → "Glossary" button
2. Document viewer menu → "View Glossary"

Features:
- Search across all terms
- Filter by category
- Tap term to view full details
- Navigable interface

### Term Detail Sheet
When tapping a highlighted term:
- Shows abbreviation prominently
- Full name below
- Color-coded category badge
- Complete definition
- Aliases (if any)
- Related terms in same category
- "Done" button to dismiss

## Performance Considerations

1. **Background Processing**: Text detection runs on background queue
2. **Lazy Highlighting**: Only highlights when view appears
3. **Efficient Pattern Matching**: Glossary uses dictionaries for O(1) lookup
4. **Memory Management**: Annotations cleaned up when highlighting disabled

## Future Enhancements (Suggestions)

1. **Persistent Preferences**: Save highlighting enabled/disabled per document
2. **Custom Highlighting Colors**: Let users choose their own color scheme
3. **Highlight Statistics**: Show count of detected terms
4. **Multi-Language Support**: Add support for other language abbreviations
5. **User-Added Terms**: Allow users to add their own custom terms
6. **Export Highlighted PDF**: Save PDF with annotations
7. **Term Usage Analytics**: Track most commonly encountered terms

## Testing Recommendations

1. Test with actual knitting patterns (PDF and images)
2. Verify OCR accuracy on various image qualities
3. Test performance with large, multi-page PDFs
4. Verify highlighting doesn't interfere with markers
5. Test term detection edge cases (punctuation, line breaks)
6. Verify all categories display correct colors
7. Test search and filter in glossary browser
