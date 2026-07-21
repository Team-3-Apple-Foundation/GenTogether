//
//  CommunityService.swift
//  GenTogether
//
//  Firestore paths:
//    communityPosts/{postId}
//    communityPosts/{postId}/comments/{commentId}
//
//  Ownership checks (userId == request.auth.uid) are enforced server-side
//  by firestore.rules; the client-side checks here exist so the UI can
//  fail fast with a friendly message instead of waiting on a permission
//  error from the server.
//

import Foundation
import FirebaseFirestore

final class CommunityService {
    static let shared = CommunityService()

    // Computed, not stored: Firestore.firestore() crashes if FirebaseApp
    // hasn't been configured, so this must only be touched after each
    // method's requireConfigured() guard below has already run.
    private var db: Firestore { Firestore.firestore() }
    private init() {}

    static let maxContentLength = 1000

    // MARK: Posts

    func fetchPosts(limit: Int = 50) async throws -> [CommunityPost] {
        try FirebaseEnvironment.requireConfigured()
        do {
            let snapshot = try await db.collection("communityPosts")
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .getDocuments()
            return try snapshot.documents.map { try $0.data(as: CommunityPost.self) }
        } catch {
            throw CommunityServiceError.readFailed(error)
        }
    }

    func createPost(userId: String, displayName: String, content: String) async throws {
        let trimmed = try Self.validated(content: content)
        try FirebaseEnvironment.requireConfigured()
        let ref = db.collection("communityPosts").document()
        let now = Date()
        let post = CommunityPost(
            userId: userId,
            displayName: displayName,
            content: trimmed,
            createdAt: now,
            updatedAt: now
        )
        do {
            try ref.setData(from: post)
        } catch {
            throw CommunityServiceError.writeFailed(error)
        }
    }

    func updateOwnPost(postId: String, userId: String, content: String) async throws {
        let trimmed = try Self.validated(content: content)
        try FirebaseEnvironment.requireConfigured()
        let ref = db.collection("communityPosts").document(postId)
        try await requireOwnership(of: ref, userId: userId, decode: CommunityPost.self, ownerId: \.userId)
        do {
            try await ref.updateData([
                "content": trimmed,
                "updatedAt": Timestamp(date: Date())
            ])
        } catch {
            throw CommunityServiceError.writeFailed(error)
        }
    }

    func deleteOwnPost(postId: String, userId: String) async throws {
        try FirebaseEnvironment.requireConfigured()
        let ref = db.collection("communityPosts").document(postId)
        try await requireOwnership(of: ref, userId: userId, decode: CommunityPost.self, ownerId: \.userId)
        do {
            try await ref.delete()
        } catch {
            throw CommunityServiceError.writeFailed(error)
        }
    }

    /// Toggles the current user's like on a post. Uses arrayUnion/arrayRemove
    /// so two people liking at once can't clobber each other's entry — no
    /// transaction needed, since each operation touches only its own userId.
    func toggleLike(postId: String, userId: String, isCurrentlyLiked: Bool) async throws {
        try FirebaseEnvironment.requireConfigured()
        let ref = db.collection("communityPosts").document(postId)
        do {
            try await ref.updateData([
                "likedBy": isCurrentlyLiked
                    ? FieldValue.arrayRemove([userId])
                    : FieldValue.arrayUnion([userId])
            ])
        } catch {
            throw CommunityServiceError.writeFailed(error)
        }
    }

    // MARK: Comments

    /// Realtime listener for a post's comments, ordered oldest-first.
    func observeComments(postId: String, onChange: @escaping (Result<[CommunityComment], Error>) -> Void) throws -> ListenerRegistration {
        try FirebaseEnvironment.requireConfigured()
        return db.collection("communityPosts").document(postId).collection("comments")
            .order(by: "createdAt")
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange(.failure(error))
                    return
                }
                guard let snapshot else { return }
                do {
                    let comments = try snapshot.documents.map { try $0.data(as: CommunityComment.self) }
                    onChange(.success(comments))
                } catch {
                    onChange(.failure(error))
                }
            }
    }

    func addComment(postId: String, userId: String, displayName: String, content: String) async throws {
        let trimmed = try Self.validated(content: content)
        try FirebaseEnvironment.requireConfigured()
        let ref = db.collection("communityPosts").document(postId).collection("comments").document()
        let now = Date()
        let comment = CommunityComment(userId: userId, displayName: displayName, content: trimmed, createdAt: now, updatedAt: now)
        do {
            try ref.setData(from: comment)
        } catch {
            throw CommunityServiceError.writeFailed(error)
        }
    }

    func updateOwnComment(postId: String, commentId: String, userId: String, content: String) async throws {
        let trimmed = try Self.validated(content: content)
        try FirebaseEnvironment.requireConfigured()
        let ref = db.collection("communityPosts").document(postId).collection("comments").document(commentId)
        try await requireOwnership(of: ref, userId: userId, decode: CommunityComment.self, ownerId: \.userId)
        do {
            try await ref.updateData([
                "content": trimmed,
                "updatedAt": Timestamp(date: Date())
            ])
        } catch {
            throw CommunityServiceError.writeFailed(error)
        }
    }

    func deleteOwnComment(postId: String, commentId: String, userId: String) async throws {
        try FirebaseEnvironment.requireConfigured()
        let ref = db.collection("communityPosts").document(postId).collection("comments").document(commentId)
        try await requireOwnership(of: ref, userId: userId, decode: CommunityComment.self, ownerId: \.userId)
        do {
            try await ref.delete()
        } catch {
            throw CommunityServiceError.writeFailed(error)
        }
    }

    /// Number of comments on a post, used for the post row's comment-count
    /// badge without downloading every comment document.
    func commentCount(postId: String) async throws -> Int {
        try FirebaseEnvironment.requireConfigured()
        do {
            let aggregate = try await db.collection("communityPosts").document(postId).collection("comments")
                .count
                .getAggregation(source: .server)
            return Int(truncating: aggregate.count)
        } catch {
            throw CommunityServiceError.readFailed(error)
        }
    }

    // MARK: Helpers

    private static func validated(content: String) throws -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CommunityServiceError.emptyContent }
        guard trimmed.count <= maxContentLength else { throw CommunityServiceError.contentTooLong }
        return trimmed
    }

    private func requireOwnership<T: Decodable>(
        of ref: DocumentReference,
        userId: String,
        decode: T.Type,
        ownerId: KeyPath<T, String>
    ) async throws {
        do {
            let snapshot = try await ref.getDocument()
            guard let value = try? snapshot.data(as: T.self), value[keyPath: ownerId] == userId else {
                throw CommunityServiceError.notOwner
            }
        } catch let error as CommunityServiceError {
            throw error
        } catch {
            throw CommunityServiceError.readFailed(error)
        }
    }
}

enum CommunityServiceError: LocalizedError {
    case emptyContent
    case contentTooLong
    case notOwner
    case readFailed(Error)
    case writeFailed(Error)

    var errorDescription: String? {
        switch self {
        case .emptyContent:
            return "Post or comment content cannot be empty."
        case .contentTooLong:
            return "That's too long — please keep it under \(CommunityService.maxContentLength) characters."
        case .notOwner:
            return "You can only edit or delete your own content."
        case .readFailed(let error):
            return "Couldn't load community content: \(error.localizedDescription)"
        case .writeFailed(let error):
            return "Couldn't save: \(error.localizedDescription)"
        }
    }
}
