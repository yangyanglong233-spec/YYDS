//
//  ContentView.swift
//  Yarn&Yarn
//
//  Created by Yangyang Long on 3/16/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \InstructionDocument.createdDate, order: .reverse) 
    private var documents: [InstructionDocument]
    
    @State private var showingImportView = false
    @State private var showingGlossary = false

    var body: some View {
        NavigationStack {
            Group {
                if documents.isEmpty {
                    ContentUnavailableView {
                        Label("No Patterns", systemImage: "doc.text.image")
                    } description: {
                        Text("Import your first knitting or crocheting pattern to get started")
                    } actions: {
                        Button {
                            showingImportView = true
                        } label: {
                            Label("Import Pattern", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(documents) { document in
                            NavigationLink {
                                DocumentViewerView(document: document)
                            } label: {
                                DocumentRowView(document: document)
                            }
                        }
                        .onDelete(perform: deleteDocuments)
                    }
                }
            }
            .navigationTitle("Yarn & Yarn")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingGlossary = true
                    } label: {
                        Label("Glossary", systemImage: "book.closed")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                        .disabled(documents.isEmpty)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingImportView = true
                    } label: {
                        Label("Import Pattern", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingImportView) {
                DocumentImportView()
            }
            .sheet(isPresented: $showingGlossary) {
                GlossaryBrowserView()
            }
        }
    }

    private func deleteDocuments(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(documents[index])
            }
        }
    }
}

struct DocumentRowView: View {
    let document: InstructionDocument
    
    var body: some View {
        HStack(spacing: 12) {
            // Document type icon
            Image(systemName: document.isPDF ? "doc.fill" : "photo.fill")
                .font(.title2)
                .foregroundStyle(document.isPDF ? .red : .blue)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(document.title)
                    .font(.headline)
                
                HStack {
                    Text(document.createdDate, format: .dateTime.month().day().year())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if !document.markers.isEmpty {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text("\(document.markers.count) marker\(document.markers.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: InstructionDocument.self, inMemory: true)
}
