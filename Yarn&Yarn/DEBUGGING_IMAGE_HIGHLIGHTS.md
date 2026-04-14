# Debugging Image Highlight Positioning

## Current Implementation

The highlight positioning uses this coordinate transformation:

### Vision Framework Coordinates
- **Origin**: Bottom-left (0,0)
- **Range**: Normalized 0.0 to 1.0
- **Y-axis**: Increases upward

### SwiftUI Coordinates  
- **Origin**: Top-left (0,0)
- **Range**: Points (actual pixel dimensions)
- **Y-axis**: Increases downward

### Transformation Formula
```swift
let visionBox = observation.boundingBox // From Vision

// Convert to SwiftUI coordinates
let x = visionBox.origin.x * imageFrame.width
let y = (1 - visionBox.origin.y - visionBox.height) * imageFrame.height
let width = visionBox.width * imageFrame.width
let height = visionBox.height * imageFrame.height
```

## How to Debug

### Step 1: Check Console Logs

When you open an image, you should see debug output like:
```
🔍 DEBUG: Found 25 text observations in image
🔍 DEBUG: Image frame: (x: 0, y: 142.5, width: 393, height: 619)
🔍 DEBUG: Text 'k2tog' at Vision box: (0.1, 0.8, 0.05, 0.02)
   → SwiftUI rect: x=39, y=123, w=19, h=12
   → Found term: 'k2tog'
```

**What to check:**
1. **Image frame**: Should match your device screen size (minus safe areas)
2. **Vision box**: Should have values between 0.0 and 1.0
3. **SwiftUI rect**: Should be reasonable coordinates within the image

### Step 2: Enable Visual Debugging

In `TextHighlightingView.swift`, find this line:
```swift
private let showDebugBoxes = false
```

Change it to:
```swift
private let showDebugBoxes = true
```

This will draw **red boxes around ALL detected text** (not just knitting terms). This helps you verify:
- The coordinate transformation is working
- Vision is detecting text correctly
- The highlights are aligned with actual text

### Step 3: Common Issues & Solutions

#### Issue: Highlights appear offset vertically
**Cause**: Y-axis flip calculation might be wrong
**Check**: Look at the console for a knitting term you can see. Is the Y coordinate reasonable?

#### Issue: Highlights are scaled wrong
**Cause**: `imageFrame` calculation might be incorrect
**Solution**: Print the actual image size vs imageFrame:
```swift
print("Image size: \(image.size)")
print("Image frame: \(imageFrame)")
```

#### Issue: No highlights appear at all
**Possible causes:**
1. No knitting terms detected → Check console for "Total knitting terms highlighted: 0"
2. Text recognition failed → Check for "Found X text observations"
3. Highlights are off-screen → Enable `showDebugBoxes` to see all text

#### Issue: Highlights in wrong position but debug boxes are correct
**Cause**: Using wrong coordinate system for highlights vs debug boxes
**Solution**: Both should use the same transformation - check the Canvas code

### Step 4: Verify Image Aspect Ratio

The `calculateImageSize` function should return the correct aspect-fit size:

```swift
// In ImageDocumentView
let imageSize = calculateImageSize(for: uiImage, in: geometry.size)
print("Container: \(geometry.size)")
print("Image displayed as: \(imageSize)")
```

### Step 5: Test with Different Images

Try with:
1. **Portrait image** (taller than wide)
2. **Landscape image** (wider than tall)
3. **Square image**
4. **Very large image** (tests scaling)
5. **Very small image** (tests scaling)

## Expected Behavior

✅ Highlights should appear directly over the knitting abbreviations
✅ Red debug boxes (if enabled) should outline all text precisely
✅ Highlights should scale with zoom
✅ Highlights should stay in position when panning

## Known Limitations

1. **Vision accuracy**: OCR isn't perfect - may miss or misread text
2. **Font dependency**: Works better with clear, sans-serif fonts
3. **Image quality**: Low resolution images may have poor text detection
4. **Skewed text**: Rotated or perspective-distorted text may not align perfectly

## If Still Not Working

Please check:
1. **Console output** - Share the debug logs
2. **Screenshot** - Show where highlights appear vs where they should be
3. **Image details** - What kind of image (screenshot, photo, PDF export)?
4. **Device** - iPhone or iPad? Screen size?

The coordinate math is:
```
Vision Y (0.8) → SwiftUI Y
1 - 0.8 - height = 0.2 - height
If height = 0.02: 0.18
Multiply by imageFrame.height (619): y = 111.42
```

This should place the highlight 111 points from the TOP of the image.
