//
//  RemoteMediaView.swift
//  GenTogether
//
//  Renders an image URL from Firestore (a full public URL into the
//  Supabase Storage `level-media` bucket) as an image. Unlike the old
//  StorageImage helper this needs no path-resolution round trip — the URL
//  is already a complete https URL — but it still has to handle a slow
//  network or a bad/missing URL gracefully, so every state (loading,
//  loaded, failed, missing) has explicit UI.
//
//  Video playback (AVKit VideoPlayer) was removed — ChallengeRound has no
//  field to distinguish image/video rounds and every round today is an
//  image. Re-add it once that data actually exists.
//

import SwiftUI

struct RemoteMediaView<Content: View, Placeholder: View, Fallback: View>: View {
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
            // No URL (nil/blank/unparsable) is a permanent state, not a
            // transient load — show the same UI as a failed load rather
            // than a spinner that will never resolve.
            fallback()
        }
    }
}
