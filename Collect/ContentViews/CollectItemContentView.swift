//
//  CollectView.swift
//  Collect
//
//  Created by Stef Kors on 14/07/2023.
//

import SwiftUI
import SwiftData
import CollectUI

struct CollectHistoryContentView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(CollectAreaView.keepsRectsStorageKey) private var keepsRects = false

    @Query private var items: [CollectItem]

    var body: some View {
        NavigationView {
            List() {
                ForEach(items) { item in
                    NavigationLink {
                        DetailItemView(item: item)
                            .toolbar(content: {
                                ToolbarItem {
                                    Button("Remove item") {
                                        deleteItem(item)
                                        //                                        selection = items.first?.id
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


            VStack {
                HStack {
                    Text("Press")
                    GroupBox {
                        Text("⌥")
                    }
                    Text("to start collecting")
                }
                Toggle("Keep rectangles pinned (esc clears)", isOn: $keepsRects)
                    .toggleStyle(.checkbox)
                HStack {
                    Text("Primary")
                        .padding()
                        .padding(.horizontal)
                        .background(.orange, in: RoundedRectangle(cornerRadius: 8))

                    Text("Secondary")
                        .padding()
                        .padding(.horizontal)
                        .background(.orange.secondary, in: RoundedRectangle(cornerRadius: 8))

                    Text("Tertiary")
                        .padding()
                        .padding(.horizontal)
                        .background(.orange.tertiary, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .toolbar(content: {
            ToolbarItem {
                Button {

                } label: {
                    Label("Information", systemImage: "info.circle.fill")
                }
            }

            ToolbarItem {
                Button(action: {
                    for item in items {
                        deleteItem(item)
                    }
                }, label: {
                    Text("Delete all items")
                        .foregroundStyle(.red)
                })
            }
        })
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
    CollectHistoryContentView()
}

struct CollectItemContentView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        CollectHistoryContentView()
            .floatingPanel(isPresented: .constant(true), ignoresMouseEvents: .constant(true), content: {
                CollectAreaView(onCollect: handleCollect)
            })
    }

    private func handleCollect(_ collected: CollectedElement) {
        withAnimation {
            modelContext.insert(CollectItem(text: collected.text, attributes: collected.attributes))
        }
    }
}

#Preview {
    CollectItemContentView()
        .modelContainer(for: CollectItem.self, inMemory: true)
}
