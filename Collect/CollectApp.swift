//
//  CollectApp.swift
//  Collect
//
//  Created by Stef Kors on 14/07/2023.
//

import SwiftUI
import SwiftData

//https://x.com/samhenrigold/status/1844157571072204838
@main
struct CollectApp: App {

    var body: some Scene {
        WindowGroup {
            CollectItemContentView()
        }
        .modelContainer(for: [LinkItem.self, CollectItem.self])
    }
}
