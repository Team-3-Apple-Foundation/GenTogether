//
//  UserService.swift
//  GenTogether
//
//  Reads and writes the users/{userId} document described in
//  FIREBASE_SETUP.md. userId is always the Firebase Authentication UID.
//

import Foundation
import FirebaseFirestore

/// Posted by `UserService.resetLocalUserState()` so any long-lived, per-user
/// view model (one that outlives a single sign-in, like `AppRootView`'s
/// `OnboardingViewModel`) can clear its own in-memory fields without
/// `UserService` needing a direct reference to it.
extension Notification.Name {
    static let userSessionDidEnd = Notification.Name("UserService.userSessionDidEnd")
}

final class UserService {
    static let shared = UserService()

    // Computed, not stored: Firestore.firestore() crashes if FirebaseApp
    // hasn't been configured, so this must only be touched after each
    // method's requireConfigured() guard below has already run.
    private var db: Firestore { Firestore.firestore() }
    private init() {}

    private func userDocument(_ userId: String) -> DocumentReference {
        db.collection("users").document(userId)
    }

    /// Creates users/{userId} the first time this UID is seen (guest or
    /// registered). Safe to call on every sign-in — it no-ops if the
    /// profile already exists so it never clobbers existing progress.
    func createUserProfileIfNeeded(
        userId: String,
        displayName: String,
        email: String?,
        accountType: AccountType
    ) async throws {
        try FirebaseEnvironment.requireConfigured()
        do {
            let snapshot = try await userDocument(userId).getDocument()
            guard !snapshot.exists else { return }
            let now = Date()
            let profile = UserProfile(
                displayName: displayName,
                email: email,
                accountType: accountType,
                createdAt: now,
                lastLoginAt: now
            )
            try userDocument(userId).setData(from: profile, merge: true)
        } catch {
            throw UserServiceError.writeFailed(error)
        }
    }

    func fetchCurrentUserProfile(userId: String) async throws -> UserProfile? {
        try FirebaseEnvironment.requireConfigured()
        do {
            let snapshot = try await userDocument(userId).getDocument()
            guard snapshot.exists else { return nil }
            return try snapshot.data(as: UserProfile.self)
        } catch {
            throw UserServiceError.readFailed(error)
        }
    }

    /// Uses `setData(merge:)` rather than `updateData` deliberately: this is
    /// called right after onboarding (guest accounts included), and
    /// `updateData` fails outright if `users/{userId}` doesn't exist yet —
    /// `setData(merge:)` writes/merges either way, so this doesn't depend on
    /// `createUserProfileIfNeeded` having already run first.
    func updateDisplayName(userId: String, displayName: String) async throws {
        guard !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw UserServiceError.invalidDisplayName
        }
        try FirebaseEnvironment.requireConfigured()
        do {
            try await userDocument(userId).setData(["displayName": displayName], merge: true)
        } catch {
            throw UserServiceError.writeFailed(error)
        }
    }

    func updateLastLogin(userId: String) async throws {
        try FirebaseEnvironment.requireConfigured()
        do {
            try await userDocument(userId).updateData(["lastLoginAt": Timestamp(date: Date())])
        } catch {
            throw UserServiceError.writeFailed(error)
        }
    }

    func updatePreferredCategories(userId: String, categories: [ChallengeCategory]) async throws {
        try FirebaseEnvironment.requireConfigured()
        do {
            try await userDocument(userId).updateData(["preferredCategories": categories.map(\.rawValue)])
        } catch {
            throw UserServiceError.writeFailed(error)
        }
    }

    /// Called on sign-out to clear any in-memory user state the app holds
    /// outside Firestore (view model caches, etc.). UserService itself has
    /// no such state — it only ever reads/writes Firestore directly — so
    /// this broadcasts a notification instead of reaching into specific
    /// view models it has no reference to.
    func resetLocalUserState() {
        NotificationCenter.default.post(name: .userSessionDidEnd, object: nil)
    }
}

enum UserServiceError: LocalizedError {
    case invalidDisplayName
    case readFailed(Error)
    case writeFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidDisplayName:
            return "Display name cannot be empty."
        case .readFailed(let error):
            return "Couldn't load your profile: \(error.localizedDescription)"
        case .writeFailed(let error):
            return "Couldn't save your profile: \(error.localizedDescription)"
        }
    }
}
