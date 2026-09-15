//
//  CollectItem.swift
//  Collect
//
//  Created by Stef Kors on 17/10/2023.
//

import Foundation
import SwiftData
import AXSwift

@Model
final class CollectItem {
    @Attribute(.unique) var timestamp: Date
    var text: String
    var attributes: [AXAttribute: String] = [:]

    init(text: String, attributes: [AXAttribute: String] = [:], timestamp: Date = .now) {
        self.text = text
        self.timestamp = timestamp
        self.attributes = attributes
    }
}
