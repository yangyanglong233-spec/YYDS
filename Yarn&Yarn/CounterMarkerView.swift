//
//  CounterMarkerView.swift
//  Yarn&Yarn
//
//  Created by Yangyang Long on 3/17/26.
//

import SwiftUI
import SwiftData

/// A visual counter marker that can be tapped to increment progress
struct CounterMarkerView: View {
    @Bindable var marker: Marker
    let geometry: any GeometryContainer
    @Environment(\.modelContext) private var modelContext
    
    @State private var isDragging = false
    @State private var showingEditor = false
    @State private var showingMenu = false
    @State private var isAnimating = false
    @State private var dragStartPositionX: CGFloat = 0
    @State private var dragStartPositionY: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 6) {
            // Label
            Text(marker.counterLabel)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            // Progress visualization
            ProgressDotsView(current: marker.currentCount, target: marker.targetCount)
            
            // Count display with fraction
            HStack(spacing: 3) {
                Text("\(marker.currentCount)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .contentTransition(.numericText())
                Text("/")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                Text("\(marker.targetCount)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .foregroundStyle(.white)
            
            // Completion indicator
            if marker.isCompleted {
                HStack(spacing: 4) {
                    HeroIcon(.checkCircle, size: 14)
                        .foregroundStyle(.white)
                    Text("Complete!")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor)
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red, lineWidth: 3) // DEBUG: Bright red border
        )
        .scaleEffect(isDragging ? 1.25 : (isAnimating ? 1.15 : 1.0))
        .position(
            x: marker.positionX * geometry.size.width,
            y: marker.positionY * geometry.size.height
        )
        .onAppear {
            print("🎨 CounterMarkerView body rendered!")
        }
        .gesture(
            DragGesture(coordinateSpace: .named("overlay"))
                .onChanged { value in
                    if !isDragging {
                        // Capture starting position on first change
                        dragStartPositionX = marker.positionX
                        dragStartPositionY = marker.positionY
                        
                        print("🔵 Dragging started - isDragging before: \(isDragging)")
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isDragging = true
                        }
                        print("🔵 Dragging started - isDragging after: \(isDragging)")
                    }
                    // Apply translation from start position
                    let delta = value.translation
                    marker.positionX = dragStartPositionX + (delta.width / geometry.size.width)
                    marker.positionY = dragStartPositionY + (delta.height / geometry.size.height)
                }
                .onEnded { _ in
                    print("🔴 Dragging ended - isDragging before: \(isDragging)")
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isDragging = false
                    }
                    print("🔴 Dragging ended - isDragging after: \(isDragging)")
                }
        )
        .onTapGesture {
            incrementCounter()
        }
        .contextMenu {
            Button {
                incrementCounter()
            } label: {
                Label("Increment (+1)", systemImage: "plus.circle")
            }
            
            Button {
                decrementCounter()
            } label: {
                Label("Decrement (-1)", systemImage: "minus.circle")
            }
            .disabled(marker.currentCount == 0)
            
            Button {
                resetCounter()
            } label: {
                Label("Reset to 0", systemImage: "arrow.counterclockwise")
            }
            .disabled(marker.currentCount == 0)
            
            Divider()
            
            Button {
                showingEditor = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            
            Button(role: .destructive) {
                // Immediately remove from parent's array
                if let doc = marker.document {
                    doc.markers.removeAll { $0.id == marker.id }
                }
                // Then delete from database
                modelContext.delete(marker)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .sheet(isPresented: $showingEditor) {
            CounterEditorView(marker: marker)
        }
    }
    
    // MARK: - Computed Properties
    
    private var backgroundColor: Color {
        if marker.isCompleted {
            return .green
        }
        return colorFromString(marker.color)
    }
    
    private func colorFromString(_ colorString: String) -> Color {
        switch colorString {
        case "blue": return .blue
        case "green": return .green
        case "red": return .red
        case "yellow": return .orange // Using orange instead of yellow for better contrast
        case "purple": return .purple
        default: return .blue
        }
    }
    
    // MARK: - Actions
    
    private func incrementCounter() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            marker.increment()
            isAnimating = true
        }
        
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        // Check for completion
        if marker.currentCount == marker.targetCount {
            celebrateCompletion()
        }
        
        // Reset animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation {
                isAnimating = false
            }
        }
    }
    
    private func decrementCounter() {
        withAnimation(.spring(response: 0.25)) {
            marker.decrement()
        }
        
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
    
    private func resetCounter() {
        withAnimation {
            marker.reset()
        }
        
        let impact = UIImpactFeedbackGenerator(style: .soft)
        impact.impactOccurred()
    }
    
    private func celebrateCompletion() {
        // Success haptic pattern
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.success)
        
        // Could add confetti animation or other celebration here in the future
    }
    
    private func deleteMarker() {
        modelContext.delete(marker)
    }
}

// MARK: - Progress Dots Visualization

/// Visual representation of progress using filled/unfilled dots
struct ProgressDotsView: View {
    let current: Int
    let target: Int
    
    private let maxDotsToShow = 8
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<min(target, maxDotsToShow), id: \.self) { index in
                Circle()
                    .fill(index < current ? Color.white : Color.white.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
            
            // Show "+n" if target exceeds max dots
            if target > maxDotsToShow {
                Text("+\(target - maxDotsToShow)")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
}

// MARK: - Alternative Progress Bar View

/// Linear progress bar visualization (alternative to dots)
struct ProgressBarView: View {
    let current: Int
    let target: Int
    
    var progress: Double {
        guard target > 0 else { return 0 }
        return min(Double(current) / Double(target), 1.0)
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 2)
                    .fill(.white.opacity(0.3))
                    .frame(height: 4)
                
                // Progress fill
                RoundedRectangle(cornerRadius: 2)
                    .fill(.white)
                    .frame(width: geo.size.width * progress, height: 4)
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Counter Editor View

/// Full-screen editor for configuring counter properties
struct CounterEditorView: View {
    @Bindable var marker: Marker
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Counter Details") {
                    TextField("Label", text: $marker.counterLabel, prompt: Text("e.g., Repeat Rows 1-4"))
                    
                    Stepper("Target: \(marker.targetCount)", value: $marker.targetCount, in: 1...999)
                    
                    HStack {
                        Text("Current Count")
                        Spacer()
                        HStack(spacing: 12) {
                            Button {
                                marker.decrement()
                            } label: {
                                HeroIcon(.minusCircle, size: 28)
                                    .foregroundStyle(marker.currentCount > 0 ? Color.blue : Color.gray)
                            }
                            .disabled(marker.currentCount == 0)
                            
                            Text("\(marker.currentCount)")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .frame(minWidth: 40)
                                .contentTransition(.numericText())
                            
                            Button {
                                marker.increment()
                            } label: {
                                HeroIcon(.plusCircle, size: 28)
                                    .foregroundStyle(Color.blue)
                            }
                        }
                    }
                }
                
                Section("Progress") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("\(marker.currentCount) of \(marker.targetCount)")
                            Spacer()
                            Text("\(Int(marker.progress * 100))%")
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                        
                        ProgressView(value: marker.progress)
                            .tint(marker.isCompleted ? .green : .blue)
                    }
                    
                    if marker.isCompleted {
                        HStack {
                            HeroIcon(.checkCircle, size: 18)
                                .foregroundStyle(Color.green)
                            Text("Completed!")
                                .fontWeight(.semibold)
                                .foregroundStyle(.green)
                        }
                    }
                }
                
                Section("Appearance") {
                    Picker("Color", selection: $marker.color) {
                        HStack {
                            Circle().fill(.blue).frame(width: 16, height: 16)
                            Text("Blue")
                        }
                        .tag("blue")
                        
                        HStack {
                            Circle().fill(.green).frame(width: 16, height: 16)
                            Text("Green")
                        }
                        .tag("green")
                        
                        HStack {
                            Circle().fill(.red).frame(width: 16, height: 16)
                            Text("Red")
                        }
                        .tag("red")
                        
                        HStack {
                            Circle().fill(.orange).frame(width: 16, height: 16)
                            Text("Orange")
                        }
                        .tag("yellow")
                        
                        HStack {
                            Circle().fill(.purple).frame(width: 16, height: 16)
                            Text("Purple")
                        }
                        .tag("purple")
                    }
                }
                
                Section {
                    Button("Reset to 0") {
                        withAnimation {
                            marker.reset()
                        }
                    }
                    .disabled(marker.currentCount == 0)
                    
                    Button("Delete Counter", role: .destructive) {
                        // Immediately remove from parent's array
                        if let doc = marker.document {
                            doc.markers.removeAll { $0.id == marker.id }
                        }
                        // Then delete from database
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

// MARK: - Previews

#Preview("Counter Marker - In Progress") {
    GeometryReader { geometry in
        let marker = Marker.counterMarker(
            label: "Repeat Rows 1-4",
            targetCount: 6,
            positionX: 0.5,
            positionY: 0.5
        )
        marker.currentCount = 3
        
        return CounterMarkerView(marker: marker, geometry: geometry)
    }
    .frame(width: 400, height: 400)
    .background(Color.gray.opacity(0.2))
}

#Preview("Counter Marker - Completed") {
    GeometryReader { geometry in
        let marker = Marker.counterMarker(
            label: "Increase Round",
            targetCount: 8,
            positionX: 0.5,
            positionY: 0.5,
            color: "green"
        )
        marker.currentCount = 8
        
        return CounterMarkerView(marker: marker, geometry: geometry)
    }
    .frame(width: 400, height: 400)
    .background(Color.gray.opacity(0.2))
}

#Preview("Counter Editor") {
    let marker = Marker.counterMarker(
        label: "Repeat Rows 1-4",
        targetCount: 6,
        positionX: 0.5,
        positionY: 0.5
    )
    marker.currentCount = 3
    
    return CounterEditorView(marker: marker)
}
