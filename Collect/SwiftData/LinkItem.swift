//
//  Item.swift
//  Collect
//
//  Created by Stef Kors on 14/07/2023.
//

import Foundation
import SwiftData
import LinkPresentation
import UniformTypeIdentifiers

@Model
final class LinkItem {
    /// The saved URL
    @Attribute(.unique) var url: URL
    /// Time of which the URL was saved
    var timestamp: Date

//
//    /// Link Metadata:
//    /// The URL that returns the metadata, taking server-side redirects into account.
//    var resolvedURL: URL? = nil
//    /// The original URL of the metadata request.
//    var originalURL: URL? = nil
//    /// A representative title for the URL.
//    var title: String? = nil
//    /// An object that retrieves data corresponding to a representative icon for the URL.
//    @Attribute(.externalStorage) var iconProvider: NSItemProvider? = nil
//    /// An object that retrieves data corresponding to a representative image for the URL.
//    @Attribute(.externalStorage) var imageProvider: NSItemProvider? = nil
//    /// A remote URL corresponding to a representative video for the URL.
//    var remoteVideoURL: URL?
//    /// An object that retrieves data corresponding to a representative video for the URL.
//    @Attribute(.externalStorage) var videoProvider: NSItemProvider? = nil
//
//    @Attribute(.externalStorage) var iconImage: NSImage? = nil
//    @Attribute(.externalStorage) var previewImage: NSImage? = nil

    init(timestamp: Date = Date(), url: URL) {
        self.timestamp = timestamp
        self.url = url
    }

    func backFillLinkInformation() async -> LinkInformation? {
            guard let meta = try? await LPMetadataProvider().startFetchingMetadata(for: self.url) else { return nil }

            return LinkInformation(
                resolvedURL: meta.url,
                originalURL: meta.originalURL,
                title: meta.title,
                iconProvider: meta.iconProvider,
                imageProvider: meta.imageProvider,
                remoteVideoURL: meta.remoteVideoURL,
                videoProvider: meta.videoProvider,
                iconImage: try? await meta.iconProvider?.toImage(),
                previewImage: try? await meta.imageProvider?.toImage()
            )
//            self.resolvedURL = meta.url
//            self.originalURL = meta.originalURL
//            self.title = meta.title
//            self.iconProvider = meta.iconProvider
//            self.iconImage = try? await meta.iconProvider?.toImage()
//            self.imageProvider = meta.imageProvider
//            self.previewImage = try? await meta.imageProvider?.toImage()
//            self.remoteVideoURL = meta.remoteVideoURL
//            self.videoProvider = meta.videoProvider
//            context.insert(self)
//        }
    }

    static let preview = LinkItem(url: URL(string: "https://dribbble.com/shots/22747423-Vector-Burger")!)
}

struct LinkInformation {
    /// Link Metadata:
    /// The URL that returns the metadata, taking server-side redirects into account.
    var resolvedURL: URL? = nil
    /// The original URL of the metadata request.
    var originalURL: URL? = nil
    /// A representative title for the URL.
    var title: String? = nil
    /// An object that retrieves data corresponding to a representative icon for the URL.
    var iconProvider: NSItemProvider? = nil
    /// An object that retrieves data corresponding to a representative image for the URL.
    var imageProvider: NSItemProvider? = nil
    /// A remote URL corresponding to a representative video for the URL.
    var remoteVideoURL: URL?
    /// An object that retrieves data corresponding to a representative video for the URL.
    var videoProvider: NSItemProvider? = nil

    var iconImage: NSImage? = nil
    var previewImage: NSImage? = nil
}

extension NSItemProvider {
    func toImage() async throws -> NSImage? {
        guard let item = try? await self.loadItem(forTypeIdentifier: UTType.image.identifier) else {
            return nil
        }

        if item is NSImage {
            return item as? NSImage
        }

        if item is URL {
            let data = try? Data(contentsOf: item as! URL)
            return NSImage(data: data!)!
        }

        if item is Data {
            return NSImage(data: item as! Data)!
        }

        return nil
    }
}

public extension URL {
    private func removeWWWPrefix(in urlString: String) -> String {
        if urlString.hasPrefix("www.") {
            return String(urlString.dropFirst("www.".count))
        }
        return urlString
    }

    /// Returns `"business.app.google.co"` from `"https://business.app.google.co"`
    var minimizedHost: String? {
        guard let host = host else { return nil }
        return removeWWWPrefix(in: host)
    }

    /// Returns `"google.co"` from `"https://business.app.google.co"`
    var mainHost: String? {
        guard let minimizedHost = minimizedHost else { return nil }
        let components = minimizedHost.split(separator: ".")
        guard components.count > 2 else { return minimizedHost }
        return components.suffix(from: components.count - 2).joined(separator: ".")
    }
}
