//
//  DetailItemView.swift
//  Collect
//
//  Created by Stef Kors on 17/01/2024.
//

import SwiftUI

struct ElementDescription: Codable, Identifiable {
    let key: String
    let value: String

    var id: String {
        self.key
    }
}

struct DetailItemView: View {
    let item: CollectItem

    @State private var tableData: [ElementDescription] = []

    @State private var sortOrder = [KeyPathComparator(\ElementDescription.key)]
    @State private var selection = Set<ElementDescription.ID>()

    let currencyStyle = Decimal.FormatStyle.Currency(code: "USD")

    var body: some View {
        VStack {
            Table(of: ElementDescription.self, selection: $selection, sortOrder: $sortOrder) {
                TableColumn("Key") { element in
                    Text(element.key)
                }
                .width(max: 200)

                TableColumn("Value") { element in
                    Text("""
\(element.value)
"""
                    )
                    .lineLimit(nil)
                }
            } rows: {
                ForEach(tableData) { desc in
                    TableRow(desc)
                }
            }
            .onChange(of: sortOrder) { _, sortOrder in
                tableData.sort(using: sortOrder)
            }
            .task(id: item.id) {
                var result: [ElementDescription] = []
                print(item.text)
                result.append(ElementDescription(key: "Joined String Value", value: item.text))

                for attribute in item.attributes {
                    result.append(ElementDescription(key: attribute.key.rawValue, value: attribute.value))
                }
                tableData = result
            }
        }
    }
}

