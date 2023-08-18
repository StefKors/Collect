//
//  DebugGridView.swift
//  Collect
//
//  Created by Stef Kors on 18/08/2023.
//

import SwiftUI

struct DebugGridView: View {
    @Binding var mouseLocation: NSPoint
    @Binding var origin: NSPoint
    @Binding var size: CGSize

    var body: some View {
        Grid(alignment: .leading) {
            Text("MouseLocation")
                .padding(.bottom, 4)
            GridRow {
                Text("x: ")
                Text(Int(mouseLocation.x).description)
                    .contentTransition(.numericText(value: mouseLocation.x))
            }

            GridRow {
                Text("y: ")
                Text(Int(mouseLocation.y).description)
                    .contentTransition(.numericText(value: mouseLocation.y))
            }

            Divider()
            Text("Origin")
                .padding(.vertical, 4)
            GridRow {
                Text("x: ")
                Text(Int(origin.x).description)
                    .contentTransition(.numericText(value: origin.x))
            }

            GridRow {
                Text("y: ")
                Text(Int(origin.y).description)
                    .contentTransition(.numericText(value: origin.y))
            }

            Divider()
            Text("Size")
                .padding(.vertical, 4)
            GridRow {
                Text("width: ")
                Text(Int(size.width).description)
                    .contentTransition(.numericText(value: size.width))
            }

            GridRow {
                Text("height: ")
                Text(Int(size.height).description)
                    .contentTransition(.numericText(value: size.height))
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(.windowBackground)
                .shadow(radius: 10)
        }
        .frame(maxWidth: 200)
    }
}

#Preview {
    DebugGridView(mouseLocation: .constant(.zero), origin: .constant(.zero), size: .constant(.zero))
}
