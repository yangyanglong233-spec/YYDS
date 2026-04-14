# Counter Marker Visual Guide

## Visual Anatomy of a Counter Marker

```
┌─────────────────────────────┐
│     Repeat Rows 1-4         │ ← Label (customizable)
│      ●●●●○○                 │ ← Progress Dots (filled = done, empty = remaining)
│        4/6                   │ ← Current/Target Fraction
└─────────────────────────────┘
   Blue background = In Progress
```

```
┌─────────────────────────────┐
│    Increase Round           │
│      ●●●●●●●●               │
│        8/8                   │
│   ✓ Complete!               │ ← Completion indicator
└─────────────────────────────┘
   Green background = Completed
```

---

## States

### State 1: Just Created (0/6)
```
┌─────────────────┐
│  Repeat         │
│  ○○○○○○         │
│  0/6            │
└─────────────────┘
```
- All dots are unfilled
- Waiting for first tap
- Blue background (default color)

### State 2: In Progress (3/6)
```
┌─────────────────┐
│  Repeat         │
│  ●●●○○○         │
│  3/6            │
└─────────────────┘
```
- 3 filled dots, 3 empty dots
- Halfway through
- Still blue background

### State 3: Almost Done (5/6)
```
┌─────────────────┐
│  Repeat         │
│  ●●●●●○         │
│  5/6            │
└─────────────────┘
```
- One more to go!
- Still blue background

### State 4: Completed (6/6)
```
┌─────────────────┐
│  Repeat         │
│  ●●●●●●         │
│  6/6            │
│  ✓ Complete!    │
└─────────────────┘
```
- All dots filled
- Green background (automatic)
- Checkmark appears
- Success haptic feedback

### State 5: Beyond Target (7/6)
```
┌─────────────────┐
│  Repeat         │
│  ●●●●●●         │
│  7/6            │
│  ✓ Complete!    │
└─────────────────┘
```
- Still shows as complete
- Allows going beyond target if needed
- Useful if pattern changes

---

## Size Variations

### Small Target (Target: 4)
```
┌─────────────────┐
│  Short Repeat   │
│  ●●○○           │
│  2/4            │
└─────────────────┘
```
Fewer dots, more compact

### Medium Target (Target: 8)
```
┌─────────────────┐
│  Standard       │
│  ●●●●●○○○       │
│  5/8            │
└─────────────────┘
```
Full 8 dots shown

### Large Target (Target: 20)
```
┌─────────────────┐
│  Long Section   │
│  ●●●●●●●● +12   │ ← "+12" indicates more beyond 8 dots
│  8/20           │
└─────────────────┘
```
Shows 8 dots max, displays "+12" for remaining

### Very Large Target (Target: 100)
```
┌─────────────────┐
│  Row Counter    │
│  ●●●●●●●● +92   │
│  8/100          │
└─────────────────┘
```
Fraction is most useful here

---

## Color Options

### Blue (Default)
```
┌─────────────────┐  🔵
│  Repeat         │  
│  ●●●○○○         │  
│  3/6            │  
└─────────────────┘  
```
Good for: General use, pattern repeats

### Green
```
┌─────────────────┐  🟢
│  Inc Round      │  
│  ●●●○○○○○       │  
│  3/8            │  
└─────────────────┘  
```
Good for: Increases, growth sections

### Red
```
┌─────────────────┐  🔴
│  Dec Round      │  
│  ●●●●○○         │  
│  4/6            │  
└─────────────────┘  
```
Good for: Decreases, critical sections

### Orange
```
┌─────────────────┐  🟠
│  Row Counter    │  
│  ●●●●●●●● +12   │  
│  12/20          │  
└─────────────────┘  
```
Good for: Rows/rounds, measurements

### Purple
```
┌─────────────────┐  🟣
│  Cable Row      │  
│  ●●●○○○         │  
│  3/6            │  
└─────────────────┘  
```
Good for: Special stitches, cables, lace

---

## Interactive States

### Normal (Idle)
```
┌─────────────────┐
│  Repeat         │  ← Regular size
│  ●●●○○○         │  
│  3/6            │  
└─────────────────┘  
```

### Tapped (Animating)
```
┌───────────────────┐
│   Repeat          │  ← Slightly larger (1.15x scale)
│   ●●●●○○          │  ← Count just increased
│   4/6             │  ← Number transitioning
└───────────────────┘  
```
Brief scale animation + haptic feedback

### Dragging
```
┌─────────────────┐
│  Repeat         │  ← Follows finger
│  ●●●○○○         │  ← Semi-transparent while moving
│  3/6            │  
└─────────────────┘  
    ↕︎ ↔︎
```
Drag to reposition on document

### Long Press Menu Open
```
┌─────────────────┐
│  Repeat         │  ← Highlighted
│  ●●●○○○         │  
│  3/6            │  
└─────────────────┘  
     │
     ├─ Increment (+1)
     ├─ Decrement (-1)
     ├─ Reset to 0
     ├─ Edit
     ├─ Delete
     └─ Cancel
```

---

## Placement Examples

### On Pattern Page
```
┌────────────────────────────────────┐
│  Pattern Instructions              │
│                                    │
│  Row 1: K1, *yo, k2tog, k4,        │
│  rep from * to last 3 sts, yo,     │  ┌──────────┐
│  k2tog, k1                         │  │ Repeat   │
│                                    │  │ ●●○○○○   │
│  Row 2: Purl                       │  │ 2/6      │
│  Row 3: K2, *yo, k2tog, k3,        │  └──────────┘
│  rep from * to last 2 sts, yo,     │      ↑
│  k2tog                             │   Counter placed
│                                    │   near relevant
│  Row 4: Purl                       │   instructions
│                                    │
│  Repeat Rows 1-4 six times.  ←─────┼─ Reference text
└────────────────────────────────────┘
```

### Multiple Counters
```
┌────────────────────────────────────┐
│  ┌──────────┐                      │
│  │ Body Inc │                      │
│  │ ●●●●○○○○ │                      │
│  │ 4/8      │                      │
│  └──────────┘                      │
│                                    │
│  [Yoke Instructions]               │
│                                    │
│              ┌──────────┐          │
│              │ Pattern  │          │
│              │ ●●●○○○   │          │
│              │ 3/6      │          │
│              └──────────┘          │
└────────────────────────────────────┘
```

---

## Editor Interface

```
┌────────────────────────────────────┐
│  ← Edit Counter              Done  │
├────────────────────────────────────┤
│                                    │
│  Counter Details                   │
│  ┌──────────────────────────────┐  │
│  │ Repeat Rows 1-4              │  │ ← Label field
│  └──────────────────────────────┘  │
│                                    │
│  Target: 6                    [±]  │ ← Stepper
│                                    │
│  Current Count          ⊖ 3 ⊕     │ ← Manual adjust
│                                    │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                    │
│  Progress                          │
│  3 of 6                      50%   │
│  ▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░             │ ← Progress bar
│                                    │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                    │
│  Appearance                        │
│  ● Blue  ○ Green  ○ Red            │ ← Color picker
│  ○ Orange  ○ Purple                │
│                                    │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                    │
│  [Reset to 0]                      │ ← Action buttons
│  [Delete Counter]                  │
│                                    │
└────────────────────────────────────┘
```

---

## Animation Sequence

### Tap to Increment

```
Frame 1 (0ms):          Frame 2 (100ms):        Frame 3 (200ms):
┌─────────────┐         ┌───────────────┐       ┌─────────────┐
│  Repeat     │         │   Repeat      │       │  Repeat     │
│  ●●●○○○     │   →     │   ●●●●○○      │  →    │  ●●●●○○     │
│  3/6        │         │   4/6         │       │  4/6        │
└─────────────┘         └───────────────┘       └─────────────┘
 Normal scale            Scaled 1.15x            Back to normal
                         Number changes          Animation complete
                         Haptic fires
```

### Completion Celebration

```
Frame 1:                Frame 2:                Frame 3:
┌─────────────┐         ┌─────────────┐         ┌─────────────┐
│  Repeat     │         │  Repeat     │         │  Repeat     │
│  ●●●●●○     │   →     │  ●●●●●●     │   →     │  ●●●●●●     │
│  5/6        │         │  6/6        │         │  6/6        │
│             │         │             │         │  ✓ Complete!│
└─────────────┘         └─────────────┘         └─────────────┘
 Blue background         Blue → Green            Green + check
                         Success haptic          Celebration!
```

---

## Comparison: Old vs New

### Before (Pen and Paper)
```
Pattern: "Repeat 6 times"

On paper:
Repeat: | | | |    ← 4 tally marks drawn
        ↑ ↑ ↑ ↑
        Each mark = completed repeat
        
Problems:
- Paper can get lost
- Hard to see at a glance
- No feedback
- Can't undo easily
- Gets messy
```

### After (Counter Marker)
```
┌─────────────────┐
│  Repeat         │
│  ●●●●○○         │
│  4/6            │
└─────────────────┘

Benefits:
✅ Lives on the pattern itself
✅ Visual progress at a glance
✅ Haptic feedback on each tap
✅ Easy to decrement if mistake
✅ Clean and organized
✅ Saves with project
✅ Can have multiple counters
```

---

## Mobile View (iPhone)

### Portrait Orientation
```
┌──────────────────────┐
│  ⋮                  │ ← Toolbar
├──────────────────────┤
│                      │
│  ┌────────┐          │
│  │Repeat  │          │
│  │●●●○○○  │          │
│  │ 3/6    │          │ ← Counter
│  └────────┘          │
│                      │
│  [Pattern Image]     │
│                      │
│                      │
│                      │
│                      │
│                      │
└──────────────────────┘
```

### Landscape Orientation
```
┌────────────────────────────────────┐
│  ⋮                                │
├────────────────────────────────────┤
│              ┌────────┐            │
│              │Repeat  │            │
│ [Pattern]    │●●●○○○  │            │
│              │ 3/6    │            │
│              └────────┘            │
└────────────────────────────────────┘
```

---

## Accessibility

### VoiceOver Labels
```
Counter reads as:
"Repeat Rows 1-4. Progress: 3 of 6. Button."

When tapped:
"Incremented to 4 of 6"

When completed:
"Complete! 6 of 6. Checkmark."
```

### Large Text Support
```
┌─────────────────────┐
│  Repeat Rows 1-4    │ ← Larger text
│  ●●●○○○             │ ← Bigger dots
│  3/6                │ ← Larger numbers
└─────────────────────┘
   ↑ Scales with Dynamic Type
```

---

## Best Practices

### ✅ Good Counter Design
```
┌─────────────────┐
│  Inc Every 6    │ ← Clear, specific label
│  ●●●●○○○○       │ ← Shows progress visually
│  4/8            │ ← Exact count visible
└─────────────────┘
  🔵 Blue          ← Meaningful color choice
```

### ❌ Avoid
```
┌─────────────────┐
│  Thing          │ ← Vague label
│  ●●●●●●●● +92   │ ← Too many (use row counter app)
│  5/100          │ ← Very large targets are hard to track
└─────────────────┘
```

---

## Summary

The counter marker replaces **pen and paper tally marks** with:
- **Visual progress** (filled/unfilled dots)
- **Exact counts** (fraction display)
- **Haptic feedback** (satisfying tap response)
- **Completion celebration** (green + checkmark)
- **Easy editing** (adjust anything anytime)
- **Persistent storage** (never lose your place)

**One tap = one tally mark**, but better! 🎉
