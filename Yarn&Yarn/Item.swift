//
//  Item.swift
//  Yarn&Yarn
//
//  Created by Yangyang Long on 3/16/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
