//
//  Item.swift
//  Collect
//
//  Created by Stef Kors on 14/07/2023.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    var text: String

    init(timestamp: Date = Date(), text: String) {
        self.timestamp = timestamp
        self.text = text
    }
}
