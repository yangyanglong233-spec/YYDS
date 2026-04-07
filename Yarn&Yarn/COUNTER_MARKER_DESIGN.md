# Counter Marker Feature Design

## Problem Statement

**Pain Point**: When following knitting patterns, knitters often need to repeat a section multiple times (e.g., "Repeat rows 1-4 six times" or "Work increase round 8 times"). Currently, knitters use pen and paper to track progress—drawing a tally mark each time they complete a repeat.

**User Story**: "As a knitter, I want to track how many times I've completed a pattern repeat so I don't lose my place and can easily see my progress."

---

## Solution: Counter Markers

A **Counter Marker** is a special type of marker that:
- Has a target count (how many times to repeat)
- Has a current count (how many times completed so far)
- Can be incremented with a single tap
- Can be decremented if you made a mistake
- Can be reset to start over
- Shows progress visually
- Optionally alerts when target is reached

---

## Design Specifications

### Data Model

We'll create a new `CounterMarker` that extends the existing `Marker` concept:

```swift
@Model
final class CounterMarker {
    var id: UUID
    var label: String // e.g., "Increase Round", "Repeat Rows 1-4"
    var currentCount: Int
    var targetCount: Int
    var positionX: Double // Position on the document
    var positionY: Double
    var pageNumber: Int // For PDFs
    var createdDate: Date
    var color: String // Visual indicator color
    var isCompleted: Bool { currentCount >= targetCount }
    var progress: Double { 
        guard targetCount > 0 else { return 0 }
        return Double(currentCount) / Double(targetCount) 
    }
    
    var document: InstructionDocument?
    
    init(
        label: String = "Counter",
        currentCount: Int = 0,
        targetCount: Int = 1,
        positionX: Double,
        positionY: Double,
        pageNumber: Int = 0,
        color: String = "blue"
    ) {
        self.id = UUID()
        self.label = label
        self.currentCount = currentCount
        self.targetCount = targetCount
        self.positionX = positionX
        self.positionY = positionY
        self.pageNumber = pageNumber
        self.createdDate = Date()
        self.color = color
    }
    
    func increment() {
        currentCount += 1
    }
    
    func decrement() {
        currentCount = max(0, currentCount - 1)
    }
    
    func reset() {
        currentCount = 0
    }
}
```

### Alternative: Unified Marker with Type

Instead of separate classes, we could add a `type` enum to the existing `Marker`:

```swift
@Model
final class Marker {
    enum MarkerType: String, Codable {
        case note = "note"
        case counter = "counter"
    }
    
    var id: UUID
    var type: MarkerType
    
    // Common properties
    var positionX: Double
    var positionY: Double
    var pageNumber: Int
    var createdDate: Date
    var color: String
    var document: InstructionDocument?
    
    // Note-specific
    var note: String
    
    // Counter-specific
    var counterLabel: String
    var currentCount: Int
    var targetCount: Int
    
    // Computed
    var isCompleted: Bool { 
        type == .counter && currentCount >= targetCount 
    }
    var progress: Double {
        guard type == .counter, targetCount > 0 else { return 0 }
        return Double(currentCount) / Double(targetCount)
    }
    
    // Convenience initializers
    static func noteMarker(/* ... */) -> Marker { /* ... */ }
    static func counterMarker(/* ... */) -> Marker { /* ... */ }
}
```

**Recommendation**: Use the unified approach—it's simpler for SwiftData queries and the relationship with `InstructionDocument`.

---

## UI/UX Design

### Visual Appearance on Document

```
┌─────────────────┐
│  Repeat 6x      │  ← Label
│  ●●●●○○         │  ← Visual progress (filled/unfilled circles)
│  4/6            │  ← Current/Target count
└─────────────────┘
```

#### States:
1. **In Progress** (currentCount < targetCount)
   - Blue/green color
   - Shows progress dots/circles
   - Shows fraction (e.g., "3/6")

2. **Completed** (currentCount >= targetCount)
   - Green/gold color with checkmark ✓
   - Optional confetti animation
   - Shows "Complete!" or "✓ 6/6"

3. **Compact Mode** (when zoomed out or space-limited)
   ```
   [6x] 4/6
   ```

### Interaction Behaviors

#### Primary Action: Tap to Increment
- **Single tap** on counter → increment by 1
- **Haptic feedback** on each increment
- **Animation**: Brief scale effect + number change
- **Completion celebration**: When reaching target, show checkmark + optional haptic "success" pattern

#### Secondary Actions (Long Press Menu):
- **Decrement** (-1): For when you make a mistake
- **Edit**: Change label, target count, color
- **Reset**: Set currentCount back to 0
- **Delete**: Remove the counter
- **Move**: Drag to reposition

#### Quick Actions (Swipe or Context Menu):
- Swipe left: Decrement
- Swipe right: Increment
- Long press: Show full menu

### Counter Creation Flow

#### Option 1: Quick Creation
1. Tap "+" button in toolbar
2. Select "Counter"
3. Defaults appear:
   - Label: "Counter"
   - Current: 0
   - Target: 6 (common repeat count)
   - Position: Center of screen
4. Tap once to place
5. Can edit immediately or start using

#### Option 2: Detailed Creation
1. Tap "+" → "Counter"
2. Sheet appears with form:
   ```
   Label: [Repeat Rows 1-4]
   Target Count: [6]
   Color: [Blue|Green|Red|Yellow|Purple]
   ```
3. Tap "Add" to place at center
4. Can drag to desired position

#### Option 3: Smart Creation (Advanced)
- If text recognition detects phrases like:
  - "Repeat 6 times"
  - "Work 8 rounds"
  - "Increase every other row 10 times"
- Offer to auto-create a counter with suggested target

---

## Implementation Phases

### Phase 1: Core Counter Functionality ✅
**Files to create/modify:**
- ✅ Update `Marker.swift` with counter properties
- ✅ Create `CounterMarkerView.swift` for the counter UI
- ✅ Update `DocumentViewerView.swift` to handle counter creation
- ✅ Add increment/decrement logic

**Features:**
- Create counter marker with label and target
- Display current/target count
- Tap to increment
- Basic editing (label, target, color)
- Delete counter

### Phase 2: Enhanced UX 🎯
**Features:**
- Visual progress indicators (dots/bar)
- Completion animation/celebration
- Haptic feedback
- Long press menu for decrement/reset
- Swipe gestures
- Compact view mode

### Phase 3: Smart Features 🚀
**Features:**
- Multiple counters per document
- Counter history (track when incremented)
- Counter templates (common patterns)
- Auto-suggest counter creation from text
- Export/share counter progress
- Statistics (average time per repeat, etc.)

---

## User Interface Mockup

### Counter Marker View (Detailed)

```swift
struct CounterMarkerView: View {
    @Bindable var marker: Marker
    let geometry: GeometryProxy
    @State private var showingEditor = false
    @State private var showingMenu = false
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 4) {
            // Label
            Text(marker.counterLabel)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
            
            // Progress visualization
            ProgressDotsView(current: marker.currentCount, target: marker.targetCount)
            
            // Count display
            HStack(spacing: 2) {
                Text("\(marker.currentCount)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .contentTransition(.numericText())
                Text("/")
                    .font(.caption)
                Text("\(marker.targetCount)")
                    .font(.caption)
            }
            .foregroundStyle(.white)
            
            // Completion indicator
            if marker.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .imageScale(.small)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor)
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        )
        .scaleEffect(isAnimating ? 1.1 : 1.0)
        .position(
            x: marker.positionX * geometry.size.width,
            y: marker.positionY * geometry.size.height
        )
        .onTapGesture {
            incrementCounter()
        }
        .onLongPressGesture {
            showingMenu = true
        }
        .confirmationDialog("Counter Actions", isPresented: $showingMenu) {
            Button("Increment (+1)") { incrementCounter() }
            Button("Decrement (-1)") { decrementCounter() }
            Button("Reset to 0") { resetCounter() }
            Button("Edit") { showingEditor = true }
            Button("Delete", role: .destructive) { deleteCounter() }
        }
        .sheet(isPresented: $showingEditor) {
            CounterEditorView(marker: marker)
        }
    }
    
    private var backgroundColor: Color {
        if marker.isCompleted {
            return .green.opacity(0.9)
        }
        return Color(marker.color).opacity(0.9)
    }
    
    private func incrementCounter() {
        withAnimation(.spring(response: 0.3)) {
            marker.currentCount += 1
            isAnimating = true
        }
        
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        // Check for completion
        if marker.currentCount == marker.targetCount {
            celebrateCompletion()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation { isAnimating = false }
        }
    }
    
    private func decrementCounter() {
        withAnimation {
            marker.currentCount = max(0, marker.currentCount - 1)
        }
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
    
    private func resetCounter() {
        withAnimation {
            marker.currentCount = 0
        }
    }
    
    private func celebrateCompletion() {
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.success)
        // Could add confetti animation here
    }
    
    private func deleteCounter() {
        // Delete from modelContext
    }
}
```

### Progress Dots Visualization

```swift
struct ProgressDotsView: View {
    let current: Int
    let target: Int
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<min(target, 10), id: \.self) { index in
                Circle()
                    .fill(index < current ? Color.white : Color.white.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
            
            // Show "+n" if target > 10
            if target > 10 {
                Text("+\(target - 10)")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
}
```

### Alternative: Progress Bar

```swift
struct ProgressBarView: View {
    let current: Int
    let target: Int
    
    var progress: Double {
        guard target > 0 else { return 0 }
        return Double(current) / Double(target)
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 2)
                    .fill(.white.opacity(0.3))
                    .frame(height: 4)
                
                // Progress
                RoundedRectangle(cornerRadius: 2)
                    .fill(.white)
                    .frame(width: geo.size.width * progress, height: 4)
            }
        }
        .frame(height: 4)
    }
}
```

---

## Counter Editor View

```swift
struct CounterEditorView: View {
    @Bindable var marker: Marker
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Label", text: $marker.counterLabel)
                    
                    Stepper("Target: \(marker.targetCount)", value: $marker.targetCount, in: 1...999)
                    
                    HStack {
                        Text("Current Count")
                        Spacer()
                        Text("\(marker.currentCount)")
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("Progress") {
                    ProgressView(value: marker.progress) {
                        HStack {
                            Text("\(marker.currentCount) of \(marker.targetCount)")
                            Spacer()
                            Text("\(Int(marker.progress * 100))%")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Section("Appearance") {
                    Picker("Color", selection: $marker.color) {
                        Text("Blue").tag("blue")
                        Text("Green").tag("green")
                        Text("Red").tag("red")
                        Text("Yellow").tag("yellow")
                        Text("Purple").tag("purple")
                    }
                    .pickerStyle(.segmented)
                }
                
                Section {
                    Button("Reset to 0") {
                        marker.currentCount = 0
                    }
                    .disabled(marker.currentCount == 0)
                    
                    Button("Delete Counter", role: .destructive) {
                        modelContext.delete(marker)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Edit Counter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
```

---

## Adding Counters to Documents

### Update DocumentViewerView Toolbar

```swift
.toolbar {
    ToolbarItem(placement: .primaryAction) {
        Menu {
            Button {
                addCounter(at: CGPoint(x: 0.5, y: 0.5))
            } label: {
                Label("Add Counter", systemImage: "number.circle")
            }
            
            Button {
                addNoteMarker(at: CGPoint(x: 0.5, y: 0.5))
            } label: {
                Label("Add Note", systemImage: "tag")
            }
            
            Divider()
            
            Toggle(isOn: $highlightingEnabled) {
                Label("Highlight Terms", systemImage: "highlighter")
            }
            
            Button {
                showingGlossary = true
            } label: {
                Label("View Glossary", systemImage: "book.closed")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }
}

private func addCounter(at position: CGPoint) {
    withAnimation {
        let newMarker = Marker.counterMarker(
            label: "Repeat",
            targetCount: 6,
            positionX: position.x,
            positionY: position.y
        )
        newMarker.document = document
        modelContext.insert(newMarker)
    }
}
```

---

## Common Use Cases

### Example 1: Increase Rounds
```
Label: "Increase Round"
Target: 8
Usage: Tap after completing each increase round
```

### Example 2: Pattern Repeat
```
Label: "Repeat Rows 1-4"
Target: 6
Usage: Tap after completing each 4-row repeat
```

### Example 3: Stitch Count Tracking
```
Label: "Yarn Over Increases"
Target: 12
Usage: Tap for each increase made
```

### Example 4: Section Progress
```
Label: "Sleeve Progress"
Target: 45 (rows)
Usage: Tap after each row
```

---

## Advanced Features (Future Enhancements)

### 1. Counter Templates
Pre-defined templates for common scenarios:
- "Repeat X times" (default: 6)
- "Increase round" (default: 8)
- "Decrease round" (default: 8)
- "Row counter" (default: 20)
- "Stitch counter" (default: 10)

### 2. Multi-Counter Coordination
- Link counters together (e.g., "Row 1" and "Row 2" alternate)
- Counter groups (all reset together)
- Conditional counters (only count if other counter at X)

### 3. Smart Suggestions
Using Vision text detection:
- Detect "repeat 6 times" → suggest counter with target=6
- Detect "work 8 rounds" → suggest counter with target=8
- Parse complex instructions automatically

### 4. Counter History
- Track timestamps of each increment
- Show average time per repeat
- Export progress log
- Undo/redo for counts

### 5. Voice Control
- "Increment counter"
- "Next repeat"
- "Reset counter"

### 6. Widget Support
- Show active counters on home screen widget
- Quick increment from widget
- Glance at progress without opening app

---

## Testing Checklist

### Functional Tests
- [ ] Create counter with custom label
- [ ] Increment counter to target
- [ ] Decrement counter
- [ ] Reset counter to 0
- [ ] Edit counter properties
- [ ] Delete counter
- [ ] Counter persists after app restart
- [ ] Multiple counters on one document
- [ ] Counter positions save correctly

### Edge Cases
- [ ] Target = 1 (single use)
- [ ] Target = 999 (very large)
- [ ] Increment beyond target (should allow)
- [ ] Decrement below 0 (should stop at 0)
- [ ] Empty label (should show placeholder)
- [ ] Very long label (should truncate)

### UI/UX Tests
- [ ] Tap response is immediate
- [ ] Haptic feedback works
- [ ] Completion animation triggers
- [ ] Colors display correctly
- [ ] Progress visualization accurate
- [ ] Counter legible at various zoom levels
- [ ] Counter draggable without accidental increments

---

## Summary

The **Counter Marker** feature transforms the manual pen-and-paper tally system into an integrated, digital solution that:

✅ **Solves the core pain point**: Track pattern repeats without external tools  
✅ **Intuitive**: Single tap to increment, just like drawing a tally  
✅ **Visual**: Clear progress indication  
✅ **Flexible**: Works for any repeat count scenario  
✅ **Integrated**: Lives directly on the pattern document  
✅ **Forgiving**: Easy to decrement if you make a mistake  
✅ **Celebratory**: Provides satisfaction when reaching the goal  

**Implementation Priority**: Phase 1 (Core Functionality) should be implemented first to validate the concept with users, then iterate based on feedback.
