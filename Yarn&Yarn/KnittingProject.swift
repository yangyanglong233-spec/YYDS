//
//  KnittingProject.swift
//  Yarn&Yarn
//

import SwiftUI
import SwiftData

@Model
final class KnittingProject {

    var id: UUID
    var name: String            // Optional — empty means "use pattern title"
    var startDate: Date
    var statusRaw: String       // Backing store for the Status enum

    @Relationship(deleteRule: .nullify)
    var pattern: InstructionDocument?

    // MARK: - Status

    enum Status: String, CaseIterable {
        case notStarted = "Not Started"
        case inProgress = "In Progress"
        case onHold     = "On Hold"
        case completed  = "Completed"

        var color: Color {
            switch self {
            case .notStarted: .secondary
            case .inProgress: .accentColor
            case .onHold:     .orange
            case .completed:  .green
            }
        }

        var icon: String {
            switch self {
            case .notStarted: "circle"
            case .inProgress: "circle.lefthalf.filled"
            case .onHold:     "pause.circle"
            case .completed:  "checkmark.circle.fill"
            }
        }
    }

    var status: Status {
        get { Status(rawValue: statusRaw) ?? .notStarted }
        set { statusRaw = newValue.rawValue }
    }

    /// The name shown in the UI — falls back to the pattern title when name is empty.
    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? (pattern?.title ?? "Untitled Project") : trimmed
    }

    // MARK: - Init

    init(
        name: String = "",
        pattern: InstructionDocument? = nil,
        startDate: Date = Date(),
        status: Status = .notStarted
    ) {
        self.id = UUID()
        self.name = name
        self.pattern = pattern
        self.startDate = startDate
        self.statusRaw = status.rawValue
    }
}
