//
//  ChallengeService.swift
//  GenTogether
//
//  Firestore paths:
//    challenges/{challengeId}
//    challenges/{challengeId}/questions/{questionId}
//    users/{userId}/challengeProgress/{challengeId}
//

import Foundation
import FirebaseFirestore

final class ChallengeService {
    static let shared = ChallengeService()

    // Computed, not stored: Firestore.firestore() crashes if FirebaseApp
    // hasn't been configured, so this must only be touched after each
    // method's requireConfigured() guard below has already run.
    private var db: Firestore { Firestore.firestore() }
    private init() {}

    func fetchActiveChallenges() async throws -> [Challenge] {
        try FirebaseEnvironment.requireConfigured()
        do {
            let snapshot = try await db.collection("challenges")
                .whereField("isActive", isEqualTo: true)
                .order(by: "challengeOrder")
                .getDocuments()
            return try snapshot.documents.map { try $0.data(as: Challenge.self) }
        } catch {
            throw ChallengeServiceError.readFailed(error)
        }
    }

    func fetchQuestions(challengeId: String) async throws -> [GameQuestion] {
        try FirebaseEnvironment.requireConfigured()
        do {
            let snapshot = try await db.collection("challenges").document(challengeId)
                .collection("questions")
                .whereField("isActive", isEqualTo: true)
                .order(by: "questionOrder")
                .getDocuments()
            return try snapshot.documents.map { try $0.data(as: GameQuestion.self) }
        } catch {
            throw ChallengeServiceError.readFailed(error)
        }
    }

    func fetchCurrentUserProgress(userId: String) async throws -> [ChallengeProgress] {
        try FirebaseEnvironment.requireConfigured()
        do {
            let snapshot = try await db.collection("users").document(userId)
                .collection("challengeProgress")
                .getDocuments()
            return try snapshot.documents.map { try $0.data(as: ChallengeProgress.self) }
        } catch {
            throw ChallengeServiceError.readFailed(error)
        }
    }

    /// Merges a new attempt into the user's progress for one challenge:
    /// bumps attemptCount, keeps the best score/star rating seen so far,
    /// and only ever moves status forward (never un-completes a challenge).
    func updateChallengeProgress(
        userId: String,
        challengeId: String,
        newStatus: ChallengeStatus,
        score: Int,
        stars: Int
    ) async throws {
        try FirebaseEnvironment.requireConfigured()
        let ref = db.collection("users").document(userId).collection("challengeProgress").document(challengeId)
        do {
            let snapshot = try await ref.getDocument()
            let now = Date()
            if snapshot.exists, let existing = try? snapshot.data(as: ChallengeProgress.self) {
                var updated = existing
                updated.attemptCount += 1
                updated.bestScore = max(updated.bestScore, score)
                updated.stars = max(updated.stars, stars)
                updated.status = updated.status == .completed ? .completed : newStatus
                if updated.status == .completed && updated.completedAt == nil {
                    updated.completedAt = now
                }
                updated.updatedAt = now
                try ref.setData(from: updated, merge: true)
            } else {
                let progress = ChallengeProgress(
                    status: newStatus,
                    bestScore: score,
                    attemptCount: 1,
                    stars: stars,
                    unlockedAt: now,
                    completedAt: newStatus == .completed ? now : nil,
                    updatedAt: now
                )
                try ref.setData(from: progress, merge: true)
            }
        } catch {
            throw ChallengeServiceError.writeFailed(error)
        }
    }

    /// Unlocks the next challenge (by `challengeOrder`) after
    /// `completedChallenge`, if it isn't already unlocked/in-progress.
    func unlockNextChallengeIfEligible(
        userId: String,
        completedChallenge: Challenge,
        allChallenges: [Challenge]
    ) async throws {
        guard let nextChallenge = allChallenges
            .filter({ $0.challengeOrder > completedChallenge.challengeOrder })
            .min(by: { $0.challengeOrder < $1.challengeOrder }),
            let nextId = nextChallenge.id else { return }

        try FirebaseEnvironment.requireConfigured()
        let ref = db.collection("users").document(userId).collection("challengeProgress").document(nextId)
        do {
            let snapshot = try await ref.getDocument()
            guard !snapshot.exists else { return }
            let progress = ChallengeProgress(
                status: .unlocked,
                bestScore: 0,
                attemptCount: 0,
                stars: 0,
                unlockedAt: Date(),
                completedAt: nil,
                updatedAt: Date()
            )
            try ref.setData(from: progress, merge: true)
        } catch {
            throw ChallengeServiceError.writeFailed(error)
        }
    }
}

enum ChallengeServiceError: LocalizedError {
    case readFailed(Error)
    case writeFailed(Error)

    var errorDescription: String? {
        switch self {
        case .readFailed(let error):
            return "Couldn't load challenges: \(error.localizedDescription)"
        case .writeFailed(let error):
            return "Couldn't save your progress: \(error.localizedDescription)"
        }
    }
}
