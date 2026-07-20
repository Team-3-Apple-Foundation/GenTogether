//
//  UserPreferences.swift
//  GenTogether
//
//  Firestore path: users/{userId}/preferences/onboarding
//  A single well-known document per user (fixed document ID "onboarding")
//  rather than an auto-generated ID, since a user has exactly one set of
//  onboarding preferences.
//

import Foundation
import FirebaseFirestore

struct UserPreferences: Codable, Identifiable, Sendable {
    @DocumentID var id: String?
    
    var aiFamiliarity: String
    var learningGoal: String
    var interests: [String]
    var learningMinutes: Int
    var textSize: TextSizePreference
    var onboardingCompleted: Bool
    var updatedAt: Date
    var name: String

    static func empty() -> UserPreferences {
        UserPreferences(
            aiFamiliarity: "",
            learningGoal: "",
            interests: [],
            learningMinutes: 10,
            textSize: .standard,
            onboardingCompleted: false,
            updatedAt: Date(),
            name: ""
        )
        
    }
}
