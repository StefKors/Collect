//
//  DebugFullWindowView.swift
//  Collect
//
//  Created by Stef Kors on 18/08/2023.
//

import SwiftUI

struct DebugFullWindowView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .strokeBorder(Color.red, lineWidth: 2)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .foregroundColor(Color.red.opacity(0.2))
            )
    }
}

#Preview {
    DebugFullWindowView()
}
