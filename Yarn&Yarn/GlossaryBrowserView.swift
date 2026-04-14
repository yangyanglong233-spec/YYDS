//
//  GlossaryBrowserView.swift
//  Yarn&Yarn
//
//  Created by Yangyang Long on 3/17/26.
//

import SwiftUI

/// Browse all knitting terminology organized by category
struct GlossaryBrowserView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedCategory: KnittingGlossary.Category?
    
    var filteredTerms: [KnittingGlossary.Term] {
        let terms = if let category = selectedCategory {
            KnittingGlossary.terms(in: category)
        } else {
            KnittingGlossary.allTerms
        }
        
        if searchText.isEmpty {
            return terms
        } else {
            return terms.filter { term in
                term.abbreviation.localizedCaseInsensitiveContains(searchText) ||
                term.fullName.localizedCaseInsensitiveContains(searchText) ||
                term.definition.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Category filter
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            CategoryFilterButton(
                                title: "All",
                                isSelected: selectedCategory == nil
                            ) {
                                selectedCategory = nil
                            }
                            
                            ForEach(KnittingGlossary.Category.allCases, id: \.self) { category in
                                CategoryFilterButton(
                                    title: category.rawValue,
                                    isSelected: selectedCategory == category
                                ) {
                                    selectedCategory = category
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                
                // Terms list
                Section {
                    if filteredTerms.isEmpty {
                        ContentUnavailableView.search
                    } else {
                        ForEach(filteredTerms, id: \.abbreviation) { term in
                            NavigationLink {
                                GlossaryTermDetailView(term: term)
                            } label: {
                                GlossaryTermRow(term: term)
                            }
                        }
                    }
                } header: {
                    if let category = selectedCategory {
                        Text(category.rawValue)
                    } else {
                        Text("\(filteredTerms.count) terms")
                    }
                }
            }
            .navigationTitle("Knitting Glossary")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search terms")
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

/// Row view for a glossary term
struct GlossaryTermRow: View {
    let term: KnittingGlossary.Term
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(term.abbreviation)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                CategoryBadge(category: term.category)
            }
            
            Text(term.fullName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

/// Filter button for categories
struct CategoryFilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    isSelected ? Color.accentColor : Color.secondary.opacity(0.1)
                )
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    GlossaryBrowserView()
}
