//
//  TutorialService.swift
//  GenTogether
//
//  Firestore path: tutorialSteps/{tutorialStepId}
//

import Foundation
import FirebaseFirestore

final class TutorialService {
    static let shared = TutorialService()

    // Computed, not stored: Firestore.firestore() crashes if FirebaseApp
    // hasn't been configured, so this must only be touched after each
    // method's requireConfigured() guard below has already run.
    private var db: Firestore { Firestore.firestore() }
    private init() {}

    func fetchActiveTutorialSteps() async throws -> [TutorialStep] {
        try FirebaseEnvironment.requireConfigured()
        do {
            let snapshot = try await db.collection("tutorialSteps")
                .whereField("isActive", isEqualTo: true)
                .order(by: "stepOrder")
                .getDocuments()
            return try snapshot.documents.map { try $0.data(as: TutorialStep.self) }
        } catch {
            throw TutorialServiceError.readFailed(error)
        }
    }
}

enum TutorialServiceError: LocalizedError {
    case readFailed(Error)

    var errorDescription: String? {
        switch self {
        case .readFailed(let error):
            return "Couldn't load the tutorial: \(error.localizedDescription)"
        }
    }
}
