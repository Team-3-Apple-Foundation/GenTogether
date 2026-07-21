//
//  CommunityCommentsViewModel.swift
//  GenTogether
//
//  Realtime comment thread for a single community post.
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class CommunityCommentsViewModel: ObservableObject {
    @Published private(set) var comments: [CommunityComment] = []
    @Published var errorMessage: String?
    @Published var draftContent: String = ""

    private let postId: String
    private let communityService: CommunityService
    private var listener: ListenerRegistration?

    init(postId: String, communityService: CommunityService? = nil) {
        self.postId = postId
        self.communityService = communityService ?? .shared
    }

    func startObserving() {
        guard listener == nil else { return }
        do {
            listener = try communityService.observeComments(postId: postId) { [weak self] result in
                guard let self else { return }
                Task { @MainActor in
                    switch result {
                    case .success(let comments):
                        self.comments = comments
                    case .failure(let error):
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stopObserving() {
        listener?.remove()
        listener = nil
    }

    func addComment(userId: String, displayName: String) async {
        errorMessage = nil
        do {
            try await communityService.addComment(postId: postId, userId: userId, displayName: displayName, content: draftContent)
            draftContent = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteComment(_ comment: CommunityComment, userId: String) async {
        guard let commentId = comment.id else { return }
        do {
            try await communityService.deleteOwnComment(postId: postId, commentId: commentId, userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateComment(_ comment: CommunityComment, newContent: String, userId: String) async {
        guard let commentId = comment.id else { return }
        do {
            try await communityService.updateOwnComment(postId: postId, commentId: commentId, userId: userId, content: newContent)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    deinit {
        listener?.remove()
    }
}
