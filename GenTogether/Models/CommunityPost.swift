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
    var communityQuestionId: String
    var content: String
    var createdAt: Date
    var updatedAt: Date
}
