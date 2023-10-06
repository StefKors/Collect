//
//  ListItem.swift
//  Collect
//
//  Created by Stef Kors on 06/10/2023.
//

import SwiftUI

struct ListItem: View {
    let item: LinkItem

    @State private var info: LinkInformation?

    var body: some View {
        ZStack(alignment: .top) {
            if let image = info?.previewImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity.animation(.snappy))
            }

        }
        .frame(minWidth: 160, idealWidth: 260, maxWidth: 460, minHeight: 60, idealHeight: 200, maxHeight: 200, alignment: .center)
        .overlay(alignment: .topLeading, content: {
            if let image = info?.iconImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20, alignment: .center)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .padding(6)
                    .transition(.opacity.animation(.snappy))
            }
        })
        //        .frame(width: 300, height: 260, alignment: .center)
        .overlay(alignment: .bottom, content: {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    if let title = info?.title {
                        Text(title)
                            .transition(.opacity.animation(.snappy))
                    } else {
                        Text(item.url.absoluteString)
                            .transition(.opacity.animation(.snappy))
                    }

                    HStack {
                        Image(systemName: "tag")
                            .symbolRenderingMode(.monochrome)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        Text("inbox")

                        Spacer()

                        if let host = item.url.mainHost {
                            Text(host)
                        }

                        Spacer()

                        Text(item.timestamp, format: .relative(presentation: .named))
                    }
                    .foregroundStyle(.secondary)
                    .font(.caption)
                }

                Spacer()
            }

            //            Spacer()
            .padding(.horizontal, 6)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        })
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.2), Color.secondary.opacity(0.1)],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        )
        .shadow(radius: 12)
        .task {
            Task.detached(priority: .low) {
                self.info = await item.backFillLinkInformation()
            }
        }
    }
}


#Preview {
    ListItem(item: .preview)
}
