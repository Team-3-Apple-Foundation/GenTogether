//
//  GameSession.swift
//  GenTogether
//
//  Firestore path: users/{userId}/gameSessions/{sessionId}
//

import Foundation
import FirebaseFirestore

struct GameSession: Codable, Identifiable, Sendable {
    @DocumentID var id: String?
    var challengeId: String
    var totalQuestions: Int
    var correctAnswers: Int
    var score: Int
    var startedAt: Date
    var completedAt: Date?
}
