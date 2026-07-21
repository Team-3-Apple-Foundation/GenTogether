//
//  CommunityComment.swift
//  GenTogether
//
//  Firestore path: communityPosts/{postId}/comments/{commentId}
//

import Foundation
import FirebaseFirestore

struct CommunityComment: Codable, Identifiable, Sendable {
    @DocumentID var id: String?
    var userId: String
    var displayName: String
    var content: String
    var createdAt: Date
    var updatedAt: Date
}
