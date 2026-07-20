//
//  Challenge.swift
//  GenTogether
//
//  Firestore path: challenges/{challengeId}
//  `mediaURL`, when present, is a full public URL into the Supabase
//  Storage `level-media` bucket — read it directly, no resolution step.
//

import Foundation
import FirebaseFirestore

struct Challenge: Codable, Identifiable, Sendable {
    @DocumentID var id: String?
    var title: String
    var description: String
    var difficulty: String
    var challengeOrder: Int
    var requiredScore: Int
    var mediaURL: String?
    var isActive: Bool
}
