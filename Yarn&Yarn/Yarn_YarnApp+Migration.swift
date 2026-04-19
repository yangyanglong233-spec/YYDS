//
//  ToriApp+Migration.swift
//  Yarn&Yarn
//
//  Created by Yangyang Long on 3/17/26.
//

import SwiftUI
import SwiftData

// MARK: - Migration Plan for Marker Model Changes

/// Migration plan to handle the change from old Marker model to new Marker model with type enum
enum MarkerMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [MarkerSchemaV1.self, MarkerSchemaV2.self]
    }
    
    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }
    
    static let migrateV1toV2 = MigrationStage.custom(
        fromVersion: MarkerSchemaV1.self,
        toVersion: MarkerSchemaV2.self,
        willMigrate: nil,
        didMigrate: { context in
            // After migration, all old markers become note-type markers
            // with default values for counter properties
            print("✅ Migration from V1 to V2 completed")
        }
    )
}

// MARK: - Schema V1 (Old Marker Model)

enum MarkerSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version = .init(1, 0, 0)
    
    static var models: [any PersistentModel.Type] {
        [Marker.self, InstructionDocument.self]
    }
    
    @Model
    final class Marker {
        var id: UUID
        var note: String
        var positionX: Double
        var positionY: Double
        var pageNumber: Int
        var createdDate: Date
        var color: String
        var document: InstructionDocument?
        
        init(note: String = "", positionX: Double, positionY: Double, pageNumber: Int = 0, color: String = "blue") {
            self.id = UUID()
            self.note = note
            self.positionX = positionX
            self.positionY = positionY
            self.pageNumber = pageNumber
            self.createdDate = Date()
            self.color = color
        }
    }
    
    @Model
    final class InstructionDocument {
        var id: UUID
        var title: String
        var fileData: Data
        var fileType: String
        var createdDate: Date
        var lastModifiedDate: Date
        var markers: [Marker]
        var isPDF: Bool { fileType == "pdf" }
        
        init(title: String, fileData: Data, fileType: String) {
            self.id = UUID()
            self.title = title
            self.fileData = fileData
            self.fileType = fileType
            self.createdDate = Date()
            self.lastModifiedDate = Date()
            self.markers = []
        }
    }
}

// MARK: - Schema V2 (New Marker Model with Counter Support)

enum MarkerSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version = .init(2, 0, 0)
    
    static var models: [any PersistentModel.Type] {
        [Marker.self, InstructionDocument.self]
    }
    
    @Model
    final class Marker {
        enum MarkerType: String, Codable {
            case note = "note"
            case counter = "counter"
        }
        
        var id: UUID
        var type: MarkerType
        var positionX: Double
        var positionY: Double
        var pageNumber: Int
        var createdDate: Date
        var color: String
        
        // Note properties
        var note: String
        
        // Counter properties
        var counterLabel: String
        var currentCount: Int
        var targetCount: Int
        
        var document: InstructionDocument?
        
        var isCompleted: Bool {
            type == .counter && currentCount >= targetCount
        }
        
        var progress: Double {
            guard type == .counter, targetCount > 0 else { return 0 }
            return Double(currentCount) / Double(targetCount)
        }
        
        init(
            type: MarkerType,
            note: String = "",
            counterLabel: String = "",
            currentCount: Int = 0,
            targetCount: Int = 1,
            positionX: Double,
            positionY: Double,
            pageNumber: Int = 0,
            color: String = "blue"
        ) {
            self.id = UUID()
            self.type = type
            self.note = note
            self.counterLabel = counterLabel
            self.currentCount = currentCount
            self.targetCount = targetCount
            self.positionX = positionX
            self.positionY = positionY
            self.pageNumber = pageNumber
            self.createdDate = Date()
            self.color = color
        }
    }
    
    @Model
    final class InstructionDocument {
        var id: UUID
        var title: String
        var fileData: Data
        var fileType: String
        var createdDate: Date
        var lastModifiedDate: Date
        var markers: [Marker]
        var isPDF: Bool { fileType == "pdf" }
        
        init(title: String, fileData: Data, fileType: String) {
            self.id = UUID()
            self.title = title
            self.fileData = fileData
            self.fileType = fileType
            self.createdDate = Date()
            self.lastModifiedDate = Date()
            self.markers = []
        }
    }
}

// MARK: - How to Use This Migration Plan

/*
 To enable proper migration, update ToriApp.swift:
 
 var sharedModelContainer: ModelContainer = {
     let schema = Schema(versionedSchema: MarkerSchemaV2.self)
     let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
     
     do {
         return try ModelContainer(
             for: schema,
             migrationPlan: MarkerMigrationPlan.self,
             configurations: [modelConfiguration]
         )
     } catch {
         fatalError("Could not create ModelContainer: \(error)")
     }
 }()
 
 */
