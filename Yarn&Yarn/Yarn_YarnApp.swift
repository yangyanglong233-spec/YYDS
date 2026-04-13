//
//  Yarn_YarnApp.swift
//  Yarn&Yarn
//
//  Created by Yangyang Long on 3/16/26.
//

import SwiftUI
import SwiftData

@main
struct Yarn_YarnApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            InstructionDocument.self,
            Marker.self,
            KnittingProject.self,
        ])
        
        // Persist data to disk so imported files and markers are saved
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // If container creation fails (e.g., due to schema migration issues),
            // delete the old store and create a fresh one
            print("⚠️ ModelContainer creation failed: \(error)")
            print("⚠️ Deleting old data store and creating fresh container...")
            
            // Get the default store URL and delete it
            let storeURL = modelConfiguration.url
            try? FileManager.default.removeItem(at: storeURL)
            // Also try to remove related files
            try? FileManager.default.removeItem(at: storeURL.deletingPathExtension().appendingPathExtension("sqlite-shm"))
            try? FileManager.default.removeItem(at: storeURL.deletingPathExtension().appendingPathExtension("sqlite-wal"))
            
            // Try creating container again with fresh store
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer even after cleanup: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
