// ComponentPlayground.swift
// Yarn&Yarn
//
// DEBUG-only view that renders every visual-only component side by side.
// Use this as a designer reference for recreating components in Figma.
// Excluded from production builds — only available in DEBUG.

#if DEBUG

import SwiftUI

struct ComponentPlayground: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxl) {
                    colorsSection
                    badgesSection
                    buttonsSection
                    progressSection
                    counterSection
                    cardSection
                    shadowSection
                }
                .padding(DesignTokens.Spacing.xl)
            }
            .navigationTitle("Component Playground")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Color Palette

    private var colorsSection: some View {
        PlaygroundSection(title: "Counter Colors") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                ForEach(DesignTokens.Colors.Counter.all, id: \.name) { item in
                    VStack(spacing: 4) {
                        Circle()
                            .fill(item.color)
                            .frame(width: 40, height: 40)
                        Text(item.name)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Category Badges

    private var badgesSection: some View {
        PlaygroundSection(title: "Category Badges") {
            FlowLayout(spacing: 8) {
                ForEach(glossaryCategories, id: \.0) { name, color in
                    Text(name)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(color.opacity(0.2))
                        .foregroundStyle(color)
                        .clipShape(Capsule())
                }
            }
        }
    }

    private let glossaryCategories: [(String, Color)] = [
        ("Basic Stitches", DesignTokens.Colors.Category.basicStitches),
        ("Increases", DesignTokens.Colors.Category.increasesDecreases),
        ("Decreases", DesignTokens.Colors.Category.increasesDecreases),
        ("Cast On", DesignTokens.Colors.Category.castOnBindOff),
        ("Bind Off", DesignTokens.Colors.Category.castOnBindOff),
        ("Cables", DesignTokens.Colors.Category.cables),
        ("Colorwork", DesignTokens.Colors.Category.colorwork),
        ("Lace", DesignTokens.Colors.Category.lace),
        ("Other", DesignTokens.Colors.Category.default),
    ]

    // MARK: - Filter Buttons

    private var buttonsSection: some View {
        PlaygroundSection(title: "Filter Pills (CategoryFilterButton)") {
            FlowLayout(spacing: 8) {
                FilterPillPreview(label: "All Terms", isSelected: true)
                FilterPillPreview(label: "Basic Stitches", isSelected: false)
                FilterPillPreview(label: "Cables", isSelected: false)
                FilterPillPreview(label: "Lace", isSelected: true)
            }
        }
    }

    // MARK: - Progress

    private var progressSection: some View {
        PlaygroundSection(title: "Progress Indicators") {
            VStack(alignment: .leading, spacing: 16) {
                Text("ProgressDotsView (4 / 8)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    ForEach(0..<8, id: \.self) { i in
                        Circle()
                            .fill(i < 4 ? DesignTokens.Colors.Counter.steel : DesignTokens.Colors.Counter.steel.opacity(0.3))
                            .frame(width: 6, height: 6)
                    }
                }

                Text("ProgressBarView (60%)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(DesignTokens.Colors.Counter.forest.opacity(0.3))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(DesignTokens.Colors.Counter.forest)
                        .frame(width: 180 * 0.6, height: 4)
                }
            }
        }
    }

    // MARK: - Counter Badge

    private var counterSection: some View {
        PlaygroundSection(title: "Counter Badges (CounterMarkerView)") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(["sage", "mauve", "steel", "plum"], id: \.self) { colorName in
                        CounterBadgePreview(colorName: colorName)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Document Card

    private var cardSection: some View {
        PlaygroundSection(title: "Document Card (DocumentCardView)") {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: 150, height: 200)
                    .overlay(
                        VStack(alignment: .leading, spacing: 8) {
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                                .fill(Color(.tertiarySystemBackground))
                                .frame(height: 120)
                            Text("Pattern Title")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 10)
                            HStack(spacing: 4) {
                                Text("knitting")
                                    .font(.caption2)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.15))
                                    .foregroundStyle(Color.accentColor)
                                    .clipShape(Capsule())
                            }
                            .padding(.horizontal, 10)
                            .padding(.bottom, 10)
                        },
                        alignment: .bottomLeading
                    )
                    .shadow(color: .black.opacity(DesignTokens.Shadow.Standard.opacity),
                            radius: DesignTokens.Shadow.Standard.radius,
                            y: DesignTokens.Shadow.Standard.y)

                Spacer()
            }
        }
    }

    // MARK: - Shadow Tokens

    private var shadowSection: some View {
        PlaygroundSection(title: "Shadows") {
            HStack(spacing: 24) {
                VStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                        .fill(.white)
                        .frame(width: 80, height: 60)
                        .shadow(color: .black.opacity(DesignTokens.Shadow.Standard.opacity),
                                radius: DesignTokens.Shadow.Standard.radius,
                                y: DesignTokens.Shadow.Standard.y)
                    Text("Standard")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                        .fill(.white)
                        .frame(width: 80, height: 60)
                        .shadow(color: Color.accentColor.opacity(DesignTokens.Shadow.Accent.opacity),
                                radius: DesignTokens.Shadow.Accent.radius,
                                y: DesignTokens.Shadow.Accent.y)
                    Text("Accent")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Helper Views

private struct PlaygroundSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            content()
        }
    }
}

private struct FilterPillPreview: View {
    let label: String
    let isSelected: Bool

    var body: some View {
        Text(label)
            .font(.subheadline)
            .padding(.horizontal, DesignTokens.Spacing.xl)
            .padding(.vertical, DesignTokens.Spacing.md)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
    }
}

private struct CounterBadgePreview: View {
    let colorName: String

    private var bg: Color { DesignTokens.Colors.Counter.color(named: colorName) }
    private var fg: Color { DesignTokens.Colors.Counter.textColor(for: colorName) }

    var body: some View {
        VStack(spacing: 6) {
            Text(colorName.capitalized)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(fg)
            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(i < 2 ? fg : fg.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
            Text("2 / 4")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(fg)
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                .fill(bg)
                .shadow(color: .black.opacity(DesignTokens.Shadow.Standard.opacity),
                        radius: DesignTokens.Shadow.Standard.radius,
                        y: DesignTokens.Shadow.Standard.y)
        )
    }
}

/// Simple wrapping horizontal layout for badge rows
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.map { $0.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0 }
                         .reduce(0) { $0 + $1 + spacing } - spacing
        return CGSize(width: proposal.width ?? 0, height: max(height, 0))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in computeRows(proposal: proposal, subviews: subviews) {
            var x = bounds.minX
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            for view in row {
                let size = view.sizeThatFits(.unspecified)
                view.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += size.width + spacing
            }
            y += rowHeight + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubview]] {
        var rows: [[LayoutSubview]] = [[]]
        var x: CGFloat = 0
        let maxWidth = proposal.width ?? .infinity
        for view in subviews {
            let w = view.sizeThatFits(.unspecified).width
            if x + w > maxWidth && !rows[rows.count - 1].isEmpty {
                rows.append([])
                x = 0
            }
            rows[rows.count - 1].append(view)
            x += w + spacing
        }
        return rows
    }
}

// MARK: - Preview

#Preview {
    ComponentPlayground()
}

#endif
