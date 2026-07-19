//
//  StorageImage.swift
//  GenTogether
//
//  Resolves a Firebase Storage path (e.g. "game-images/flower-001.jpg")
//  to a downloadable URL and renders it with AsyncImage, mirroring
//  AsyncImage's content/placeholder API so it drops in anywhere AsyncImage
//  would be used.
//

import SwiftUI

struct StorageImage<Content: View, Placeholder: View>: View {
    let path: String?
    @ViewBuilder var content: (Image) -> Content
    @ViewBuilder var placeholder: () -> Placeholder

    @State private var resolvedURL: URL?

    var body: some View {
        Group {
            if let resolvedURL {
                AsyncImage(url: resolvedURL) { phase in
                    if let image = phase.image {
                        content(image)
                    } else {
                        placeholder()
                    }
                }
            } else {
                placeholder()
            }
        }
        .task(id: path) {
            resolvedURL = nil
            guard let path, !path.isEmpty else { return }
            resolvedURL = try? await StorageService.shared.downloadURL(forStoragePath: path)
        }
    }
}
