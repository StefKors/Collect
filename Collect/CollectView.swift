//
//  CollectView.swift
//  Collect
//
//  Created by Stef Kors on 14/07/2023.
//

import SwiftUI
import SwiftData
//
//struct CollectView: View {
//    @Environment(\.modelContext) private var modelContext
//    @Query private var items: [Item]
//
//    @State private var collect: Bool = false
//
//    var body: some View {
//        NavigationView {
//            List {
//                ForEach(items) { item in
//                    NavigationLink {
//                        VStack {
//                            Text("Item at \(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))")
//                            Text(item.text)
//                        }
//                        .toolbar(content: {
//                            ToolbarItem {
//                                Button("Remove item") {
//                                    deleteItem(item)
//                                }
//                            }
//                        })
//                    } label: {
//                        // Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
//                        Text(item.text)
//                            .truncationMode(.tail)
//                            .lineLimit(1)
//                    }
//                }
//                .onDelete(perform: deleteItems)
//            }
//
//
//            HStack {
//                Text("Press")
//                GroupBox {
//                    Text("⌥")
//                }
//                Text("to start collecting")
//            }
//            .floatingPanel(isPresented: .constant(true), content: {
//                CollectAreaContentView(onCollect: handleCollect)
//            })
//        }
//        .toolbar(content: {
//            ToolbarItem {
//                Button {
//                    
//                } label: {
//                    Label("Information", systemImage: "info.circle.fill")
//                }
//            }
//        })
//
//    }
//
//    private func handleCollect(_ text: String) {
//        addItem(text: text)
//    }
//
//    private func enableCollect() {
//        collect.toggle()
//    }
//
//    private func addItem(text: String) {
//        withAnimation {
////            let newItem = Item(text: text)
////            modelContext.insert(newItem)
//        }
//    }
//
//    private func deleteItem(_ item: Item) {
//        withAnimation {
//            modelContext.delete(item)
//        }
//    }
//
//    private func deleteItems(offsets: IndexSet) {
//        withAnimation {
//            for index in offsets {
//                modelContext.delete(items[index])
//            }
//        }
//    }
//}
//
//#Preview {
//    CollectView()
//        .modelContainer(for: Item.self, inMemory: true)
//}
