# Tutorial Video Setup Guide

## Overview
This guide explains how to add tutorial videos/GIFs to your knitting glossary terms.

## Folder Structure

### Step 1: Create Resources Folder in Xcode

1. In Xcode, right-click on your project name (`Yarn&Yarn`)
2. Select **New Group**
3. Name it `Resources`
4. Right-click on `Resources`, create another **New Group**
5. Name it `StitchTutorials`

Your structure should look like:
```
Yarn&Yarn/
├── ContentView.swift
├── Resources/
│   └── StitchTutorials/
│       ├── (your video files go here)
```

### Step 2: Add Video Files

1. Record or obtain your tutorial videos
2. Name them to match the term abbreviations:
   - `k.mp4` - for knit stitch
   - `p.mp4` - for purl stitch
   - `k2tog.mp4` - for knit 2 together
   - `yo.mp4` - for yarn over
   - etc.

3. Drag the video files into the `StitchTutorials` folder in Xcode
4. **IMPORTANT**: When prompted, make sure to:
   - ✅ Check "Copy items if needed"
   - ✅ Check your app target
   - ✅ Select "Create folder references" (not groups)

## Supported Video Formats

The player supports:
- **.mp4** (recommended - best compatibility)
- **.mov** (QuickTime)
- **.m4v** (H.264 video)

### Video Recommendations

**For Best User Experience:**
- **Duration**: 5-15 seconds (looping)
- **Resolution**: 720p (1280x720) is plenty for mobile
- **File Size**: Keep under 5MB per video
- **Frame Rate**: 30fps is fine
- **Orientation**: Landscape or square (1:1 ratio works great)
- **No Audio Needed**: These are visual demonstrations

**Compression Tips:**
- Use H.264 codec
- Medium quality is sufficient
- Consider using Handbrake or similar tools to compress

## How to Add Videos to Terms

In `TextHighlightingView.swift`, when defining terms, add the `tutorialVideo` parameter:

```swift
Term("k", "knit", "Insert the right needle...", 
     category: .basicStitches, 
     tutorialVideo: "k")  // ← Add this
```

**Note**: Don't include the file extension (`.mp4`) - just the name.

## Video File Naming Convention

Match the abbreviation exactly (case-insensitive):

| Term | Video Filename |
|------|---------------|
| k | `k.mp4` |
| p | `p.mp4` |
| k2tog | `k2tog.mp4` |
| yo | `yo.mp4` |
| ssk | `ssk.mp4` |
| M1L | `M1L.mp4` or `m1l.mp4` |
| ktbl | `ktbl.mp4` |

## Terms Already Set Up with Video Support

I've already added `tutorialVideo` parameters to these terms:
- k, p, k2tog, p2tog
- ssk, ssp
- kfb, pfb
- yo
- sl, sl1k, sl1p
- ktbl, ptbl

To add more, just follow the pattern in the code.

## Video Player Features

The tutorial video player:
- ✅ **Auto-plays** when the modal opens
- ✅ **Loops automatically** - perfect for learning repetitive motions
- ✅ **Pauses** when the modal is dismissed
- ✅ **Shows placeholder** if video not found (with "Coming soon!" message)
- ✅ **Built-in controls** (play/pause, scrubbing, fullscreen)

## Alternative: Using GIFs

If you prefer GIFs over videos:

### Option 1: Convert GIF to MP4
GIFs are much larger than MP4 videos. I recommend converting them:
- Use online tools like CloudConvert or ezgif.com
- Convert GIF → MP4
- This drastically reduces file size while maintaining quality

### Option 2: Use a GIF Library
If you must use GIFs, you'll need to add a GIF player library like SDWebImageSwiftUI:

1. Add package: `https://github.com/SDWebImage/SDWebImageSwiftUI.git`
2. Modify `TutorialVideoPlayer` to handle GIFs

**I recommend MP4 videos** - they're much more efficient!

## Testing

### To test without videos:
1. Build and run the app
2. Tap any highlighted term (like `k1` or `p2`)
3. You'll see a placeholder saying "Tutorial video not available - Coming soon!"

### To test with videos:
1. Add at least one video (e.g., `k.mp4`) to `Resources/StitchTutorials/`
2. Make sure it's in the target
3. Build and run
4. Tap a `k` or `k1` term
5. Video should auto-play and loop!

## Batch Video Creation Ideas

### Option 1: Screen Record Yourself
1. Use your phone camera
2. Record your hands doing the stitch
3. Keep it short (5-10 seconds)
4. Trim and export as MP4

### Option 2: Use Existing Resources
Many knitting websites offer free tutorial videos:
- Check Creative Commons licensed content
- Give proper attribution if required
- Ensure commercial use is allowed for your app

### Option 3: Create Animated Diagrams
- Use animation software to create simple diagrams
- Export as video
- Clean, professional look

## Example Video Recording Setup

**Minimal Setup:**
```
Phone on tripod → Record hands doing stitch → Transfer to computer → Compress → Add to Xcode
```

**Recommended Lighting:**
- Good natural light or ring light
- Light-colored yarn shows up best
- Neutral background

## Troubleshooting

### Video doesn't appear:
1. Check the file is in the Xcode project navigator
2. Verify target membership (select file → File Inspector → Target Membership)
3. Check filename matches exactly (case-insensitive)
4. Build → Clean Build Folder → Rebuild

### Video is too large:
1. Compress using Handbrake (free)
2. Settings: H.264, 720p, Medium quality
3. Trim to essential motion only

### Video doesn't loop:
1. Check that the code includes the looping logic (it does!)
2. Make sure video file isn't corrupted

## Future Enhancements

Ideas for later:
- [ ] Add slow-motion playback option
- [ ] Allow users to favorite/bookmark stitches
- [ ] Download videos on-demand to reduce app size
- [ ] Add left-handed versions
- [ ] Multi-angle views
- [ ] Step-by-step breakdowns with scrubbing

## Summary

1. **Create** `Resources/StitchTutorials/` folder in Xcode
2. **Record** or source your tutorial videos
3. **Name** them to match term abbreviations (e.g., `k.mp4`)
4. **Drag** into Xcode with "Copy items if needed" checked
5. **Add** `tutorialVideo` parameter to terms in code
6. **Build** and test!

The feature is ready to go - you just need to add the video files! 🎥🧶
