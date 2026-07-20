//
//  RemoteMediaView.swift
//  GenTogether
//
//  Renders a media URL from Firestore (a full public URL into the
//  Supabase Storage `level-media` bucket) as either an image or an inline
//  video. Which one is the caller's call via `isImage` — the data source
//  (ChallengeRound.isImage) is authoritative, not a guess from the URL's
//  file extension, since Supabase/CDN URLs aren't guaranteed to carry one.
//  Unlike the old StorageImage helper this needs no path-resolution round
//  trip — the URL is already a complete https URL — but it still has to
//  handle a slow network or a bad/missing URL gracefully, so every state
//  (loading, loaded, failed, missing) has explicit UI.
//

import SwiftUI
import AVKit

struct RemoteMediaView<Content: View, Placeholder: View, Fallback: View>: View {
    let urlString: String?
    let isImage: Bool
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
            if isImage {
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
            } else {
                RemoteVideoPlayer(url: mediaURL, placeholder: placeholder, fallback: fallback)
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
