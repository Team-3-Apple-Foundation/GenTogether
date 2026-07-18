//
//  GameAnswer.swift
//  GenTogether
//
//  Firestore path: users/{userId}/gameSessions/{sessionId}/answers/{answerId}
//

import Foundation
import FirebaseFirestore

struct GameAnswer: Codable, Identifiable, Sendable {
    @DocumentID var id: String?
    var questionId: String
    var selectedAnswer: SelectedAnswer
    var isCorrect: Bool
    var responseTimeSeconds: Double
    var answeredAt: Date
}
