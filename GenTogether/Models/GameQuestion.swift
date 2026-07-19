//
//  GameQuestion.swift
//  GenTogether
//
//  Firestore path: challenges/{challengeId}/questions/{questionId}
//

import Foundation
import FirebaseFirestore

struct GameQuestion: Codable, Identifiable, Sendable {
    @DocumentID var id: String?
    var imagePath: String
    var imageType: ImageType
    var correctAnswer: SelectedAnswer
    var hint: String?
    var explanation: String?
    var questionOrder: Int
    var isActive: Bool
}
