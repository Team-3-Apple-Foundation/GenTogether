//
//  ChallengeProgress.swift
//  GenTogether
//
//  Firestore path: users/{userId}/challengeProgress/{challengeId}
//  The document ID intentionally equals the challenge ID (not an
//  auto-generated ID) so there is exactly one progress record per
//  user/challenge pair.
//

import Foundation
import FirebaseFirestore

struct ChallengeProgress: Codable, Identifiable, Sendable {
    @DocumentID var id: String?
    var status: ChallengeStatus
    var bestScore: Int
    var attemptCount: Int
    var stars: Int
    var unlockedAt: Date?
    var completedAt: Date?
    var updatedAt: Date
}
