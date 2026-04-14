//
//  GlossaryTermDetailView.swift
//  Yarn&Yarn
//
//  Quick reference file to document the expected structure
//  This file should already exist in your project
//

/*
 Expected structure based on usage in the codebase:
 
 struct GlossaryTermDetailView: View {
     let term: KnittingGlossary.Term
     
     var body: some View {
         // Display term details:
         // - term.abbreviation
         // - term.fullName  
         // - term.definition
         // - term.category
         // - term.tutorialVideoName (optional)
     }
 }
 
 This view is presented as a sheet when:
 1. User taps a highlighted terminology term in a PDF
 2. User taps a highlighted terminology term in an image
 3. User selects a term from the GlossaryBrowserView
 */
