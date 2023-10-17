//
//  CollectItem.swift
//  Collect
//
//  Created by Stef Kors on 17/10/2023.
//

import Foundation
import SwiftData

@Model
final class CollectItem {
    @Attribute(.unique) let timestamp: Date
    let text: String

    init(text: String, timestamp: Date = .now) {
        self.text = text
        self.timestamp = timestamp
    }
}
