//
//  InstructionDocument.swift
//  Yarn&Yarn
//
//  Created by Yangyang Long on 3/16/26.
//

import Foundation
import SwiftData
import UniformTypeIdentifiers

@Model
final class InstructionDocument {
    var id: UUID
    var title: String
    var createdDate: Date
    var fileData: Data
    var fileType: String // "pdf" or "image"
    
    @Relationship(deleteRule: .cascade, inverse: \Marker.document)
    var markers: [Marker] = []
    
    init(title: String, fileData: Data, fileType: String) {
        self.id = UUID()
        self.title = title
        self.createdDate = Date()
        self.fileData = fileData
        self.fileType = fileType
    }
    
    var isPDF: Bool {
        fileType == "pdf"
    }
    
    var isImage: Bool {
        fileType == "image"
    }
}
