//
//  PdfDeepLinkView.swift
//  Collect
//
//  Created by Stef Kors on 05/02/2024.
//

import SwiftUI

extension URL {
// https://stackoverflow.com/questions/34060754/how-can-i-build-a-url-with-query-parameters-containing-multiple-values-for-the-s
    func appending(_ queryItem: String, value: String?) -> URL {

        guard var urlComponents = URLComponents(string: absoluteString) else { return absoluteURL }

        // Create array of existing query items
        var queryItems: [URLQueryItem] = urlComponents.queryItems ??  []

        // Create query item
        let queryItem = URLQueryItem(name: queryItem, value: value)

        // Append the new query item in the existing query items array
        queryItems.append(queryItem)

        // Append updated query items array in the url component object
        urlComponents.queryItems = queryItems

        // Returns the url from new url components
        return urlComponents.url!
    }
}

struct PdfDeepLinkView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack {
            Text("PDF Deeplink")

            Button {
                print("click")
                let url = URL(fileURLWithPath: "/Users/stefkors/Downloads/TestPaper.pdf")
                let finalURL = url.appending("page", value: "3")
                print("opening url: \(url.description) \(finalURL.description)")
                NSWorkspace.shared.open(finalURL)

                let config = NSWorkspace.OpenConfiguration()
                // can i use the config to open a specific page?
                NSWorkspace.shared.open(finalURL, configuration: config)
//                    openURL(url)

            } label: {
                Text("Open")
            }

        }
    }
}

#Preview {
    PdfDeepLinkView()
}
