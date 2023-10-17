//
//  ContentView.swift
//  Collect
//
//  Created by Stef Kors on 06/10/2023.
//

import SwiftUI
import SwiftData

struct LinkItemContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    
    @Query(sort: \LinkItem.timestamp, order: .reverse) private var items: [LinkItem]
    
    @State private var isHovering: Bool = false
    @State private var input: String = ""
    
    private let columns = [GridItem(.adaptive(minimum: 260))]
    
    var body: some View {
        VStack {
            ScrollView(.vertical) {
                LazyVGrid(columns: columns) {
                    ForEach(items) { item in
                        ListItem(item: item)
                            .onTapGesture {
                                openURL(item.url)
                            }
                    }
                    .onDelete(perform: deleteItems)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .scrollClipDisabled()
            .overlay(alignment: .bottom) {
                TextField("URL", text: $input)
                    .onSubmit {
                        if let url = URL(string: input) {
                            addItem(url)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .scenePadding()
                    .frame(maxWidth: 400)
            }

            Spacer()
        }
        .padding()
    }
    
    private func addItem(_ url: URL) {
        withAnimation {
            let newItem = LinkItem(timestamp: Date(), url: url)
            modelContext.insert(newItem)
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

#Preview {
    LinkItemContentView()
        .modelContainer(for: LinkItem.self, inMemory: true)
}
