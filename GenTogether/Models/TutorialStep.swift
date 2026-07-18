//
//  TutorialStep.swift
//  GenTogether
//
//  Firestore path: tutorialSteps/{tutorialStepId}
//  `imagePath` is a Firebase Storage path (e.g. "tutorial-images/step-1.png"),
//  never a downloadable URL — resolve it with StorageService at render time.
//

import Foundation
import FirebaseFirestore

struct TutorialStep: Codable, Identifiable, Sendable {
    @DocumentID var id: String?
    var title: String
    var description: String
    var imagePath: String?
    var stepOrder: Int
    var isActive: Bool
}
