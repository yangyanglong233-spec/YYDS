# Marker Palette UI Guide

## Instagram Story-Style Marker Palette

The marker palette now appears as a floating panel on the top-right of the document, similar to Instagram Stories stickers!

### Visual Design

```
                                    ┌─────────────────┐
                                    │  Add Markers    │
                                    ├─────────────────┤
                                    │                 │
                                    │  ┌───────────┐  │
                                    │  │   📊      │  │
                                    │  │   0/6     │  │ ← Counter button (Blue)
                                    │  └───────────┘  │
                                    │    Counter      │
                                    │                 │
                                    │  ┌───────────┐  │
                                    │  │   📝      │  │ ← Note button (Orange)
                                    │  └───────────┘  │
                                    │    Note         │
                                    │                 │
                                    └─────────────────┘
```

### Behavior

**Tap "Counter" →** Adds a counter marker (0/6) to the center of the document
**Tap "Note" →** Adds a note marker to the center of the document

### Visual States

#### Counter Button
- **Background:** Blue gradient with shadow
- **Icon:** Number circle (📊)
- **Preview:** Shows "0/6" to indicate it's a counter
- **Label:** "Counter" below the button

#### Note Button
- **Background:** Orange gradient with shadow
- **Icon:** Note icon (📝)
- **Label:** "Note" below the button

### Placement

The palette floats in the **top-right corner** of the screen:
```
┌────────────────────────────────────┐
│  Pattern Title           [Palette] │ ← Top-right
├────────────────────────────────────┤
│                                    │
│  [Your Pattern Image/PDF]          │
│                                    │
│                                    │
│                                    │
│                                    │
└────────────────────────────────────┘
```

### Interaction Flow

1. **User views pattern document**
2. **Sees floating palette** on the right side
3. **Taps "Counter"** → Counter marker appears in the center
4. **Drags counter** to desired position on pattern
5. **Taps counter** to increment count

### Future Enhancement: Drag & Drop

In a future update, we can add Instagram-style drag & drop:
- **Long press** on palette button
- **Drag** to position on document
- **Release** to drop marker at that exact position

For now, tapping adds to center and user can drag to reposition.

---

## Comparison to Instagram Stories

### Instagram Stories Stickers
```
Tap sticker icon → Palette appears → Tap sticker type → Appears on screen → Drag to position
```

### Yarn&Yarn Markers
```
See palette → Tap marker type → Appears on document → Drag to position
```

**Key Difference:** Our palette is **always visible** for quick access (better for knitting workflow where you frequently add counters).

---

## Alternative Menu (Still Available)

The old menu is still accessible via the **⋯ (ellipsis)** button:
```
⋯ Menu
├─ Add Marker
│  ├─ Counter
│  └─ Note
├─ Highlight Terms (toggle)
└─ View Glossary
```

This gives users **two ways** to add markers:
1. **Quick:** Tap palette (always visible)
2. **Menu:** Use ⋯ button (traditional)

---

## Colors & Styling

### Palette Container
- Background: `.ultraThinMaterial` (frosted glass effect)
- Corner radius: 16pt
- Shadow: Subtle drop shadow for depth
- Padding: 12pt all around

### Buttons
- Size: 50x50pt squares
- Corner radius: 10pt
- Gradient backgrounds
- Individual shadows for "lifted" appearance

### Typography
- Header: "Add Markers" - Caption, semibold, secondary color
- Labels: "Counter" / "Note" - Caption2, medium, secondary color

---

## Accessibility

### VoiceOver Labels
- "Add counter marker button"
- "Add note marker button"

### Interaction
- Large tap targets (50x50pt minimum)
- Clear visual distinction between types
- High contrast icons and text

---

## Implementation Notes

The palette is implemented in `DocumentViewerView.swift`:

```swift
MarkerPaletteView(
    isDragging: $isDraggingMarker,
    onAddCounter: {
        addCounter(at: CGPoint(x: 0.5, y: 0.5))
    },
    onAddNote: {
        addNoteMarker(at: CGPoint(x: 0.5, y: 0.5))
    }
)
```

It's positioned in a `ZStack` above the document content but below the navigation bar.
