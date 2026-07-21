//
//  CommunityPost.swift
//  GenTogether
//
//  Firestore path: communityPosts/{postId}
//

import Foundation
import FirebaseFirestore

struct CommunityPost: Codable, Identifiable, Sendable {
    @DocumentID var id: String?
    var userId: String
    var displayName: String
    var content: String
    var createdAt: Date
    var updatedAt: Date
    var likedBy: [String] = []

    var likeCount: Int { likedBy.count }

    func isLiked(by userId: String) -> Bool {
        likedBy.contains(userId)
    }
}
