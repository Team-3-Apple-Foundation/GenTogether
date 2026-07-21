//
//  PreferenceService.swift
//  GenTogether
//
//  Firestore path: users/{userId}/preferences/onboarding
//

import Foundation
import FirebaseFirestore

final class PreferenceService {
    static let shared = PreferenceService()

    // Computed, not stored: Firestore.firestore() crashes if FirebaseApp
    // hasn't been configured, so this must only be touched after each
    // method's requireConfigured() guard below has already run.
    private var db: Firestore { Firestore.firestore() }
    private init() {}

    private func preferencesDocument(userId: String) -> DocumentReference {
        db.collection("users").document(userId).collection("preferences").document("onboarding")
    }

    func saveOnboardingPreferences(userId: String, preferences: UserPreferences) async throws {
        try FirebaseEnvironment.requireConfigured()
        var toSave = preferences
        toSave.updatedAt = Date()
        do {
            try preferencesDocument(userId: userId).setData(from: toSave, merge: true)
        } catch {
            throw PreferenceServiceError.writeFailed(error)
        }
    }

    func fetchOnboardingPreferences(userId: String) async throws -> UserPreferences? {
        try FirebaseEnvironment.requireConfigured()
        do {
            let snapshot = try await preferencesDocument(userId: userId).getDocument()
            guard snapshot.exists else { return nil }
            return try snapshot.data(as: UserPreferences.self)
        } catch {
            throw PreferenceServiceError.readFailed(error)
        }
    }

    func checkOnboardingCompletion(userId: String) async throws -> Bool {
        try await fetchOnboardingPreferences(userId: userId)?.onboardingCompleted ?? false
    }
}

enum PreferenceServiceError: LocalizedError {
    case readFailed(Error)
    case writeFailed(Error)

    var errorDescription: String? {
        switch self {
        case .readFailed(let error):
            return "Couldn't load your preferences: \(error.localizedDescription)"
        case .writeFailed(let error):
            return "Couldn't save your preferences: \(error.localizedDescription)"
        }
    }
}
