//
//  GeometryContainer.swift
//  Yarn&Yarn
//
//  Created by Yangyang Long on 3/23/26.
//

import SwiftUI

/// Protocol to allow both GeometryProxy and custom wrappers to be used with views that need geometry
protocol GeometryContainer {
    var size: CGSize { get }
}

/// Make SwiftUI's GeometryProxy conform to our protocol
extension GeometryProxy: GeometryContainer {}

/// A simple wrapper that mimics SwiftUI's GeometryProxy for use in UIKit contexts
struct GeometryProxyWrapper: GeometryContainer {
    let size: CGSize
}
