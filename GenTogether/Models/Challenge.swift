//
//  Challenge.swift
//  GenTogether
//
//  Firestore path: challenges/{challengeId}
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
    var imagePath: String?
    var isActive: Bool
}
