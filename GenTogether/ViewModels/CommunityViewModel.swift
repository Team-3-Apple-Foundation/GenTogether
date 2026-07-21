//
//  CommunityViewModel.swift
//  GenTogether
//
//  Loads the community feed and drives create/edit/delete/like for the
//  current user's own posts.
//

import Foundation
import Combine

@MainActor
final class CommunityViewModel: ObservableObject {
    @Published private(set) var posts: [CommunityPost] = []
    @Published private(set) var commentCounts: [String: Int] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var draftContent: String = ""

    private let communityService: CommunityService

    init(communityService: CommunityService? = nil) {
        self.communityService = communityService ?? .shared
    }

    var isEmpty: Bool { !isLoading && posts.isEmpty }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            posts = try await communityService.fetchPosts()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Fetched lazily per row (rather than in `load()`) so opening the
    /// community feed doesn't pay for N extra aggregate queries up front.
    func loadCommentCount(for post: CommunityPost) async {
        guard let postId = post.id, commentCounts[postId] == nil else { return }
        if let count = try? await communityService.commentCount(postId: postId) {
            commentCounts[postId] = count
        }
    }

    func createPost(userId: String, displayName: String) async {
        errorMessage = nil
        do {
            try await communityService.createPost(
                userId: userId,
                displayName: displayName,
                content: draftContent
            )
            draftContent = ""
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updatePost(_ post: CommunityPost, newContent: String, userId: String) async {
        guard let postId = post.id else { return }
        errorMessage = nil
        do {
            try await communityService.updateOwnPost(postId: postId, userId: userId, content: newContent)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deletePost(_ post: CommunityPost, userId: String) async {
        guard let postId = post.id else { return }
        errorMessage = nil
        do {
            try await communityService.deleteOwnPost(postId: postId, userId: userId)
            posts.removeAll { $0.id == postId }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleLike(_ post: CommunityPost, userId: String) async {
        guard let postId = post.id else { return }
        let isLiked = post.isLiked(by: userId)

        // Optimistic update: flip the local copy immediately so the heart
        // responds on tap, then reconcile with the server.
        if let index = posts.firstIndex(where: { $0.id == postId }) {
            if isLiked {
                posts[index].likedBy.removeAll { $0 == userId }
            } else {
                posts[index].likedBy.append(userId)
            }
        }

        do {
            try await communityService.toggleLike(postId: postId, userId: userId, isCurrentlyLiked: isLiked)
        } catch {
            // Roll back the optimistic change on failure.
            if let index = posts.firstIndex(where: { $0.id == postId }) {
                if isLiked {
                    posts[index].likedBy.append(userId)
                } else {
                    posts[index].likedBy.removeAll { $0 == userId }
                }
            }
            errorMessage = error.localizedDescription
        }
    }
}
