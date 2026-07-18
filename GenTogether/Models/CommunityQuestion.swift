//
//  CommunityQuestion.swift
//  GenTogether
//
//  Firestore path: communityQuestions/{communityQuestionId}
//

import Foundation
import FirebaseFirestore

struct CommunityQuestion: Codable, Identifiable, Sendable {
    @DocumentID var id: String?
    var question: String
    var displayDate: Date
    var isActive: Bool
}
