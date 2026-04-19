// Icons.swift
// Yarn&Yarn
//
// Type-safe Heroicons v2 wrapper.
// Run scripts/setup_heroicons.sh to populate Assets.xcassets/Icons/ before building.
//
// Usage:
//   HeroIcon(.magnifyingGlass)                 // 16 pt, inherits foregroundStyle color
//   HeroIcon(.plus, size: 20)                  // explicit size
//   HeroIcon(.checkCircle, size: 14).foregroundStyle(.green)

import SwiftUI

// MARK: - AppIcon

/// Type-safe reference to a Heroicons v2 SVG asset in Assets.xcassets/Icons/.
/// Asset names follow the pattern: hi-<style>-<heroicon-name>
enum AppIcon: String {

    // MARK: Outline — 24 × 24 viewport, 1.5 pt strokes

    case magnifyingGlass          = "hi-outline-magnifying-glass"
    case magnifyingGlassCircle    = "hi-outline-magnifying-glass-circle"
    case plus                     = "hi-outline-plus"
    case minus                    = "hi-outline-minus"
    case check                    = "hi-outline-check"
    case pencil                   = "hi-outline-pencil"
    case pencilSquare             = "hi-outline-pencil-square"
    case trash                    = "hi-outline-trash"
    case photo                    = "hi-outline-photo"
    case document                 = "hi-outline-document"
    case clock                    = "hi-outline-clock"
    case ellipsisHorizontalCircle = "hi-outline-ellipsis-horizontal-circle"
    case videoSlash               = "hi-outline-video-camera-slash"
    case pauseCircle              = "hi-outline-pause-circle"
    case squaresGrid              = "hi-outline-squares-2x2"
    case listBullet               = "hi-outline-list-bullet"
    case lockClosed               = "hi-outline-lock-closed"

    // MARK: Solid — 24 × 24 viewport, filled

    case xCircle                  = "hi-solid-x-circle"
    case lockClosedFilled         = "hi-solid-lock-closed"
    case documentFilled           = "hi-solid-document"
    case photoFilled              = "hi-solid-photo"
    case clockFilled              = "hi-solid-clock"
    case checkCircle              = "hi-solid-check-circle"
    case minusCircle              = "hi-solid-minus-circle"
    case plusCircle               = "hi-solid-plus-circle"
    case pauseCircleFilled        = "hi-solid-pause-circle"

    // MARK: Mini — 20 × 20 viewport, thicker strokes (optimised for small sizes)

    case chevronRight             = "hi-mini-chevron-right"
}

// MARK: - HeroIcon

/// SwiftUI view that renders a Heroicons SVG as a template image.
///
/// The icon inherits its color from the nearest `.foregroundStyle()` in the view
/// hierarchy — the same behaviour as `Image(systemName:)`.
///
/// Default size is `DesignTokens.Typography.sizeMD` (16 pt), matching the most
/// common icon usage in the app. Override with the `size` parameter or by
/// chaining `.frame(width:height:)` after the view.
struct HeroIcon: View {
    let icon: AppIcon
    var size: CGFloat

    init(_ icon: AppIcon, size: CGFloat = DesignTokens.Typography.sizeMD) {
        self.icon = icon
        self.size = size
    }

    var body: some View {
        Image(icon.rawValue)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}

// MARK: - StatusIconView

/// Renders the correct icon for a `KnittingProject.Status` value.
///
/// - `notStarted` → open circle (SwiftUI shape)
/// - `inProgress` → half-filled circle (SwiftUI shape)
/// - `onHold`     → pause-circle Heroicon
/// - `completed`  → check-circle Heroicon
struct StatusIconView: View {
    let status: KnittingProject.Status
    var size: CGFloat = 18

    var body: some View {
        Group {
            switch status {
            case .notStarted:
                Circle()
                    .stroke(DesignTokens.Colors.Status.notStarted, lineWidth: 1.5)

            case .inProgress:
                ZStack {
                    Circle()
                        .stroke(DesignTokens.Colors.Status.inProgress, lineWidth: 1.5)
                    Circle()
                        .trim(from: 0, to: 0.5)
                        .fill(DesignTokens.Colors.Status.inProgress)
                        .rotationEffect(.degrees(-90))
                }

            case .onHold:
                HeroIcon(.pauseCircle, size: size)
                    .foregroundStyle(DesignTokens.Colors.Status.onHold)

            case .completed:
                HeroIcon(.checkCircle, size: size)
                    .foregroundStyle(DesignTokens.Colors.Status.completed)
            }
        }
        .frame(width: size, height: size)
    }
}
