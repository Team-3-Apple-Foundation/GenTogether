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

    // MARK: Account deletion

    /// Displayed in place of the real name on any post/comment written by
    /// a since-deleted account — Reddit-style. The content, likes, and
    /// comment threads underneath are left completely untouched; only this
    /// one field changes.
    static let deletedUserDisplayName = "[deleted user]"

    /// Reassigns `displayName` (never `userId` — Firebase never reuses
    /// UIDs, so the old value stays harmless) on every post and comment
    /// this user authored. Must run while `userId` is still the signed-in
    /// user: firestore.rules requires `resource.data.userId == request.auth.uid`
    /// for these updates, so this has to happen before
    /// `AuthService.deleteCurrentUser()` ends that session.
    ///
    /// Finding every comment needs a `collectionGroup("comments")` query
    /// (comments live under each individual post, not one shared
    /// collection) — Firestore requires a matching collection-group index
    /// for that query to run; the first live attempt will fail with a
    /// direct console link to create it if it's missing.
    func anonymizeContent(forDeletedUserId userId: String) async throws {
        try FirebaseEnvironment.requireConfigured()

        // Each step logs its own path/verb *before* attempting it, and the
        // exact Firestore error domain/code if it fails — so a permission
        // error here points at one specific query or write instead of
        // leaving three candidates to guess between.
        let posts: QuerySnapshot
        do {
            #if DEBUG
            print("[CommunityService] READ communityPosts where userId == \(userId)")
            #endif
            posts = try await db.collection("communityPosts")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            #if DEBUG
            print("[CommunityService] READ communityPosts — found \(posts.documents.count) document(s)")
            #endif
        } catch {
            Self.debugLogFailure("READ communityPosts where userId == \(userId)", error)
            throw CommunityServiceError.readFailed(error)
        }

        let comments: QuerySnapshot
        do {
            #if DEBUG
            print("[CommunityService] READ collectionGroup(comments) where userId == \(userId)")
            #endif
            comments = try await db.collectionGroup("comments")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            #if DEBUG
            print("[CommunityService] READ collectionGroup(comments) — found \(comments.documents.count) document(s)")
            #endif
        } catch {
            Self.debugLogFailure("READ collectionGroup(comments) where userId == \(userId)", error)
            throw CommunityServiceError.readFailed(error)
        }

        // The exact payload sent for every document in this batch — named
        // once so the log below and the actual write below it are
        // provably the same dictionary, not just similar-looking code.
        let updatePayload: [String: Any] = ["displayName": Self.deletedUserDisplayName]

        #if DEBUG
        print("[CommunityService] update payload for every document in this batch: \(updatePayload) — keys: \(Array(updatePayload.keys))")

        // Dumps exactly the fields firestore.rules' allow-update conditions
        // check (userId, createdAt, content, and — for posts —
        // communityQuestionId), read straight from what's actually stored,
        // rather than what the Swift model assumes is there. createdAt is
        // decoded to its raw .seconds/.nanoseconds so a genuine precision
        // mismatch would actually be visible here — a Timestamp's default
        // description can visually round away exactly that.
        for document in posts.documents {
            let data = document.data()
            let createdAt = data["createdAt"] as? Timestamp
            // `data.keys.contains(...)` distinguishes "key absent from the
            // document entirely" (Swift dictionary lookup returns nil
            // because there's nothing there) from "key present, value is
            // Firestore's null" (lookup returns Optional(NSNull) — still
            // prints via String(describing:), but the key genuinely
            // exists). Firestore Rules treats a dot-accessed *missing* key
            // very differently from an *explicit null* value — the former
            // can throw a rule-evaluation error, which Firestore denies by
            // default, surfacing as the same permission-denied message.
            let hasCommunityQuestionIdKey = data.keys.contains("communityQuestionId")
            print("""
            [CommunityService] pre-update snapshot — communityPosts/\(document.documentID): \
            userId=\(String(describing: data["userId"])), \
            createdAt.seconds=\(String(describing: createdAt?.seconds)), \
            createdAt.nanoseconds=\(String(describing: createdAt?.nanoseconds)), \
            communityQuestionId key present?=\(hasCommunityQuestionIdKey), \
            communityQuestionId value=\(String(describing: data["communityQuestionId"])), \
            content=\(String(describing: data["content"])) (\(type(of: data["content"])))
            """)
        }
        for document in comments.documents {
            let data = document.data()
            let content = data["content"] as? String
            let createdAt = data["createdAt"] as? Timestamp
            print("""
            [CommunityService] pre-update snapshot — \(document.reference.path): \
            userId=\(String(describing: data["userId"])), \
            createdAt.seconds=\(String(describing: createdAt?.seconds)), \
            createdAt.nanoseconds=\(String(describing: createdAt?.nanoseconds)), \
            content=\(String(describing: content)), \
            content.count(Swift chars)=\(content?.count ?? -1), \
            content UTF8 byte size (what firestore.rules' .size() actually checks)=\(content?.utf8.count ?? -1)
            """)
        }
        #endif

        #if DEBUG
        // Isolated diagnostic: the exact same updateData(_:) call, on the
        // exact same document, with NO WriteBatch involved at all — rules
        // out (or confirms) WriteBatch itself as a variable, separate from
        // whatever's denying the batched version below. Non-fatal: this is
        // purely diagnostic, so a failure here doesn't stop the real flow.
        await Self.debugIsolatedSingleDocumentUpdateTest(db: db, updatePayload: updatePayload)
        #endif

        let batch = db.batch()
        for document in posts.documents {
            batch.updateData(updatePayload, forDocument: document.reference)
        }
        for document in comments.documents {
            batch.updateData(updatePayload, forDocument: document.reference)
        }

        do {
            #if DEBUG
            print("[CommunityService] UPDATE (batch) \(posts.documents.count) post(s) + \(comments.documents.count) comment(s) — displayName -> \"\(Self.deletedUserDisplayName)\"")
            #endif
            try await batch.commit()
            #if DEBUG
            print("[CommunityService] UPDATE (batch) committed successfully")
            #endif
        } catch {
            Self.debugLogFailure("UPDATE (batch) displayName on \(posts.documents.count) post(s) + \(comments.documents.count) comment(s)", error)
            throw CommunityServiceError.writeFailed(error)
        }
    }

    private static func debugLogFailure(_ operation: String, _ error: Error) {
        #if DEBUG
        let nsError = error as NSError
        print("[CommunityService] FAILED \(operation) — domain: \(nsError.domain), code: \(nsError.code), message: \(nsError.localizedDescription)")
        #endif
    }

    #if DEBUG
    /// Isolated repro: the exact same field update, on the exact same
    /// known-failing document, called directly with no WriteBatch — rules
    /// out WriteBatch semantics as a variable, separate from whatever's
    /// denying the batched version. Hardcoded path is deliberate; this is
    /// a temporary diagnostic, not something meant to stay long-term.
    private static func debugIsolatedSingleDocumentUpdateTest(db: Firestore, updatePayload: [String: Any]) async {
        let path = "communityPosts/egACwAiyRLL92udBcqNX/comments/nUD4CNpAe7ed9U23M2wn"
        let ref = db.document(path)
        print("[CommunityService] ISOLATED TEST — single (non-batch) UPDATE at \(path) with payload \(updatePayload)")
        do {
            try await ref.updateData(updatePayload)
            print("[CommunityService] ISOLATED TEST — succeeded")
        } catch {
            let nsError = error as NSError
            print("[CommunityService] ISOLATED TEST — FAILED — domain: \(nsError.domain), code: \(nsError.code), message: \(nsError.localizedDescription)")
        }
    }
    #endif

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
