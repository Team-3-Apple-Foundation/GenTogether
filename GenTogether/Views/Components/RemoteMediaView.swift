//
//  RemoteMediaView.swift
//  GenTogether
//
//  Renders a `mediaURL` from Firestore (a full public URL into the
//  Supabase Storage `level-media` bucket) as either an image or an inline
//  video, picked by the URL's file extension. Unlike the old StorageImage
//  helper this needs no path-resolution round trip — mediaURL is already
//  a complete https URL — but it still has to handle a slow network or a
//  bad/missing URL gracefully, so every state (loading, loaded, failed,
//  missing) has explicit UI.
//

import SwiftUI
import AVKit

struct RemoteMediaView<Content: View, Placeholder: View, Fallback: View>: View {
    private static var videoExtensions: Set<String> { ["mp4", "mov", "m4v", "webm"] }

    let urlString: String?
    @ViewBuilder var content: (Image) -> Content
    @ViewBuilder var placeholder: () -> Placeholder
    @ViewBuilder var fallback: () -> Fallback

    private var mediaURL: URL? {
        guard let urlString, !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return URL(string: urlString)
    }

    var body: some View {
        if let mediaURL {
            if Self.videoExtensions.contains(mediaURL.pathExtension.lowercased()) {
                RemoteVideoPlayer(url: mediaURL, placeholder: placeholder, fallback: fallback)
            } else {
                AsyncImage(url: mediaURL) { phase in
                    switch phase {
                    case .empty:
                        placeholder()
                    case .success(let image):
                        content(image)
                    case .failure:
                        fallback()
                    @unknown default:
                        fallback()
                    }
                }
            }
        } else {
            // No URL (nil/blank/unparsable) is a permanent state, not a
            // transient load — show the same UI as a failed load rather
            // than a spinner that will never resolve.
            fallback()
        }
    }
}

/// Inline video playback for a remote URL, with explicit loading/error
/// states driven by observing the player item's status (AVPlayer gives no
/// callback-based API for this, only KVO/status polling).
private struct RemoteVideoPlayer<Placeholder: View, Fallback: View>: View {
    let url: URL
    @ViewBuilder var placeholder: () -> Placeholder
    @ViewBuilder var fallback: () -> Fallback

    @State private var player: AVPlayer?
    @State private var didFail = false
    @State private var statusObservation: NSKeyValueObservation?

    var body: some View {
        Group {
            if didFail {
                fallback()
            } else if let player {
                VideoPlayer(player: player)
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            didFail = false
            player = nil
            let item = AVPlayerItem(url: url)
            let newPlayer = AVPlayer(playerItem: item)
            statusObservation = item.observe(\.status) { item, _ in
                Task { @MainActor in
                    switch item.status {
                    case .readyToPlay:
                        player = newPlayer
                    case .failed:
                        didFail = true
                    case .unknown:
                        break
                    @unknown default:
                        break
                    }
                }
            }
        }
        .onDisappear {
            statusObservation?.invalidate()
            player?.pause()
        }
    }
}
