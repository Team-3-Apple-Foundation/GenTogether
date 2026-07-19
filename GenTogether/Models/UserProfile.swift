//
//  UserProfile.swift
//  GenTogether
//
//  Firestore path: users/{userId}
//  The document ID is always the Firebase Authentication UID (shared by
//  guest and registered accounts alike).
//

import Foundation
import FirebaseFirestore

struct UserProfile: Codable, Identifiable, Sendable {
    @DocumentID var id: String?
    var displayName: String
    var email: String?
    var accountType: AccountType
    var createdAt: Date
    var lastLoginAt: Date
}
