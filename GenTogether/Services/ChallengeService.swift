//
//  ChallengeService.swift
//  GenTogether
//
//  Firestore path: challenges/{challengeId}
//

import Foundation
import FirebaseFirestore

final class ChallengeService {
    static let shared = ChallengeService()

    // Computed, not stored: Firestore.firestore() crashes if FirebaseApp
    // hasn't been configured, so this must only be touched after
    // requireConfigured() below has already run.
    private var db: Firestore { Firestore.firestore() }
    private init() {}

    /// All challenges, sorted by category for a stable list order (there's
    /// no ordering field in Firestore to sort by server-side). Document IDs
    /// are Firestore auto-generated — the caller must read `.id` off each
    /// result rather than assuming any fixed id.
    func fetchChallenges() async throws -> [Challenge] {
        try FirebaseEnvironment.requireConfigured()
        do {
            let snapshot = try await db.collection("challenges").getDocuments()
            let challenges = try snapshot.documents.map { try $0.data(as: Challenge.self) }
            return challenges.sorted { $0.category.rawValue < $1.category.rawValue }
        } catch {
            print("ChallengeService: failed to list challenges — \(error)")
            throw ChallengeServiceError.readFailed(id: nil, underlying: error)
        }
    }

    func fetchChallenge(id: String) async throws -> Challenge {
        try FirebaseEnvironment.requireConfigured()
        do {
            let snapshot = try await db.collection("challenges").document(id).getDocument()
            guard snapshot.exists else {
                print("ChallengeService: no document at challenges/\(id).")
                throw ChallengeServiceError.notFound(id: id)
            }
            do {
                return try snapshot.data(as: Challenge.self)
            } catch {
                // Most likely cause during manual data entry: a field is
                // missing or has the wrong type (e.g. category isn't one of
                // the ChallengeCategory raw values). This does NOT crash
                // the app — it's a normal thrown error, caught right here.
                print("ChallengeService: challenges/\(id) exists but failed to decode — \(error)")
                throw ChallengeServiceError.decodeFailed(id: id, underlying: error)
            }
        } catch let error as ChallengeServiceError {
            throw error
        } catch {
            if Self.isPermissionDenied(error) {
                print("""
                ChallengeService: permission denied reading challenges/\(id) (Firestore \
                code 7 — PERMISSION_DENIED). This is a Security Rules problem, not app \
                code: check firestore.rules has a \
                `match /challenges/{challengeId} { allow read: if true; }` block, and \
                that it's actually been deployed with \
                `firebase deploy --only firestore:rules` (editing the local file alone \
                doesn't affect the live project).
                """)
                throw ChallengeServiceError.permissionDenied(id: id, underlying: error)
            }
            print("ChallengeService: failed to fetch challenges/\(id) — \(error)")
            throw ChallengeServiceError.readFailed(id: id, underlying: error)
        }
    }

    private static func isPermissionDenied(_ error: Error) -> Bool {
        (error as NSError).code == FirestoreErrorCode.permissionDenied.rawValue
    }
}

enum ChallengeServiceError: LocalizedError {
    case notFound(id: String)
    case decodeFailed(id: String, underlying: Error)
    case permissionDenied(id: String, underlying: Error)
    case readFailed(id: String?, underlying: Error)

    var errorDescription: String? {
        switch self {
        case .notFound(let id):
            return "No challenge found with id \"\(id)\"."
        case .decodeFailed(let id, let underlying):
            return "Challenge \"\(id)\" has bad data: \(underlying.localizedDescription)"
        case .permissionDenied(let id, _):
            return "No permission to read challenge \"\(id)\" — check Firestore Security Rules for /challenges."
        case .readFailed(let id, let underlying):
            if let id {
                return "Couldn't load challenge \"\(id)\": \(underlying.localizedDescription)"
            }
            return "Couldn't load challenges: \(underlying.localizedDescription)"
        }
    }
}
