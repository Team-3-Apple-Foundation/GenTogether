//
//  GameQuestion.swift
//  GenTogether
//
//  Firestore path: challenges/{challengeId}/questions/{questionId}
//  `mediaURL` is a full public URL into the Supabase Storage `level-media`
//  bucket (e.g. "https://<project>.supabase.co/storage/v1/object/public/
//  level-media/flower-001.jpg"), not a Firebase Storage path — read it
//  directly with AsyncImage/AVPlayer, no resolution step needed.
//

import Foundation
import FirebaseFirestore

struct GameQuestion: Codable, Identifiable, Sendable {
    @DocumentID var id: String?
    var mediaURL: String
    var imageType: ImageType
    var correctAnswer: SelectedAnswer
    var hint: String?
    var explanation: String?
    var questionOrder: Int
    var isActive: Bool
}
