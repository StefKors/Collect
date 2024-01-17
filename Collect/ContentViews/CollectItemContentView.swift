//
//  CollectView.swift
//  Collect
//
//  Created by Stef Kors on 14/07/2023.
//

import SwiftUI
import SwiftData

struct CollectItemContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [CollectItem]

    @State private var collect: Bool = false

    @State private var selection: CollectItem.ID? = nil

    var body: some View {
        NavigationView {
            List(selection: $selection) {
                ForEach(items) { item in
                    NavigationLink {
                        DetailItemView(item: item)
                            .toolbar(content: {
                                ToolbarItem {
                                    Button("Remove item") {
                                        deleteItem(item)
                                        selection = items.first?.id
                                    }
                                }
                            })
                    } label: {
                        // Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                        Text(item.text)
                            .truncationMode(.tail)
                            .lineLimit(1)
                    }
                }
                .onDelete(perform: deleteItems)
            }


            HStack {
                Text("Press")
                GroupBox {
                    Text("⌥")
                }
                Text("to start collecting")
            }
            .floatingPanel(isPresented: .constant(true), ignoresMouseEvents: .constant(true), content: {
                CollectAreaView(onCollect: handleCollect)
            })
        }
        .toolbar(content: {
            ToolbarItem {
                Button {

                } label: {
                    Label("Information", systemImage: "info.circle.fill")
                }
            }
        })
    }

    private func handleCollect(_ item: CollectItem) {
        addItem(item: item)
    }

    private func enableCollect() {
        collect.toggle()
    }

    private func addItem(item: CollectItem) {
        withAnimation {
            modelContext.insert(item)
        }
    }

    private func deleteItem(_ item: CollectItem) {
        withAnimation {
            modelContext.delete(item)
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
    CollectItemContentView()
        .modelContainer(for: CollectItem.self, inMemory: true)
}
