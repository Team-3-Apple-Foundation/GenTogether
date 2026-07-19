//
//  CommunityViewModel.swift
//  GenTogether
//
//  Loads the active community question and its posts, and drives
//  create/edit/delete for the current user's own posts.
//

import Foundation
import Combine

@MainActor
final class CommunityViewModel: ObservableObject {
    @Published private(set) var activeQuestion: CommunityQuestion?
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
            activeQuestion = try await communityService.fetchActiveCommunityQuestion()
            posts = try await communityService.fetchPosts(communityQuestionId: activeQuestion?.id)
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
        guard let questionId = activeQuestion?.id else {
            errorMessage = "There's no community question to post under yet."
            return
        }
        errorMessage = nil
        do {
            try await communityService.createPost(
                userId: userId,
                displayName: displayName,
                communityQuestionId: questionId,
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
}
