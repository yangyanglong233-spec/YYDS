# Image Highlighting Fix - Character-Level Precision

## Problem Identified

The highlights were covering **entire lines of text** instead of just the knitting terms because Vision framework's `VNRecognizedTextObservation` returns a bounding box for the complete text line, not individual words.

### Example from Console
```
Text: '• ÆПН: (s11 wyif, 1F) 1R2iX, sl1 wyif, AtiZSl, 11 (13, 15) (17, 19, 21) -'
Vision box: (0.044, 0.225, 0.796, 0.023)  ← Entire line!
Found term: 'sl'  ← But we only want this word
```

## Solution

Use Vision's **character-level bounding box** API to get precise positions for each matched term:

```swift
// Get the range of the term within the full text
let nsRange = NSRange(match.range, in: text)

// Get precise bounding box for JUST this term
if let termBox = try? topCandidate.boundingBox(for: nsRange) {
    let normalizedBox = termBox.boundingBox
    // Now we have the exact box for "sl" instead of the whole line
}
```

## How It Works

1. **Line detection**: Vision detects entire lines (e.g., "Row 1: k2, p2, kfb")
2. **Term matching**: Our glossary finds "k2", "p2", "kfb" in that line
3. **Character ranges**: We get the position of each term (e.g., "kfb" is at characters 13-15)
4. **Precise boxes**: Vision gives us the exact bounding box for just those characters
5. **Highlight**: We draw a small box around just "kfb", not the whole line

## Benefits

✅ **Precise highlights** - Only covers the actual knitting abbreviation
✅ **Multiple terms per line** - Can highlight "k2", "p2", and "kfb" separately  
✅ **Better UX** - Clear which term you're tapping on
✅ **Accurate tap detection** - Smaller hit areas = more precise taps

## Example Output

Before:
```
[====================================]  ← Entire line highlighted
Row 1: k2, p2, kfb
```

After:
```
Row 1: [k2], [p2], [kfb]  ← Only terms highlighted
```

## Fallback Handling

If character-level bounding box fails (rare), we fall back to the line box:
```swift
} else {
    print("⚠️ WARNING: Could not get precise box for '\(term)', using line box")
    // Use observation.boundingBox as fallback
}
```

This ensures highlights always appear, even if precision isn't perfect.

## Testing

Run the app and check console. You should now see:
```
🔍 DEBUG: Found term 'kfb' at precise box: (0.15, 0.39, 0.05, 0.02)
```

The width (0.05) should now be much smaller than before (was 0.34 for whole line).

## Performance Note

Character-level bounding boxes are slightly more expensive to compute, but the difference is negligible for typical knitting patterns (< 100 terms per image).
