//
//  TutorialStep.swift
//  GenTogether
//
//  Firestore path: tutorialSteps/{tutorialStepId}
//  `mediaURL` is a full public URL into the Supabase Storage `level-media`
//  bucket (e.g. "https://<project>.supabase.co/storage/v1/object/public/
//  level-media/step-1.png") — read it directly with AsyncImage/AVPlayer,
//  no path resolution step needed.
//

import Foundation
import FirebaseFirestore

struct TutorialStep: Codable, Identifiable, Sendable {
    @DocumentID var id: String?
    var title: String
    var description: String
    var mediaURL: String?
    var stepOrder: Int
    var isActive: Bool
}
