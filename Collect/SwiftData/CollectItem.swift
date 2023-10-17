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
    let text: String
    let timestamp: Date

    init(text: String, timestamp: Date = .now) {
        self.text = text
        self.timestamp = timestamp
    }
}
