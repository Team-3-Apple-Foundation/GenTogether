//
//  GameService.swift
//  GenTogether
//
//  Firestore paths:
//    users/{userId}/gameSessions/{sessionId}
//    users/{userId}/gameSessions/{sessionId}/answers/{answerId}
//    users/{userId}/challengeProgress/{challengeId}
//

import Foundation
import FirebaseFirestore

final class GameService {
    static let shared = GameService()

    // Computed, not stored: Firestore.firestore() crashes if FirebaseApp
    // hasn't been configured, so this must only be touched after each
    // method's requireConfigured() guard below has already run.
    private var db: Firestore { Firestore.firestore() }
    private init() {}

    private func sessionsCollection(userId: String) -> CollectionReference {
        db.collection("users").document(userId).collection("gameSessions")
    }

    func startGameSession(userId: String, challengeId: String, totalQuestions: Int) async throws -> GameSession {
        try FirebaseEnvironment.requireConfigured()
        let ref = sessionsCollection(userId: userId).document()
        let session = GameSession(
            challengeId: challengeId,
            totalQuestions: totalQuestions,
            correctAnswers: 0,
            score: 0,
            startedAt: Date(),
            completedAt: nil
        )
        do {
            try ref.setData(from: session)
            var saved = session
            saved.id = ref.documentID
            return saved
        } catch {
            throw GameServiceError.writeFailed(error)
        }
    }

    func saveAnswer(userId: String, sessionId: String, answer: GameAnswer) async throws {
        try FirebaseEnvironment.requireConfigured()
        let ref = sessionsCollection(userId: userId).document(sessionId).collection("answers").document()
        do {
            try ref.setData(from: answer)
        } catch {
            throw GameServiceError.writeFailed(error)
        }
    }

    /// Score is the percentage of correct answers, 0...100.
    static func score(correct: Int, total: Int) -> Int {
        guard total > 0 else { return 0 }
        return Int((Double(correct) / Double(total)) * 100)
    }

    static func stars(forScore score: Int) -> Int {
        switch score {
        case 90...100: return 3
        case 70..<90: return 2
        case 1..<70: return 1
        default: return 0
        }
    }

    /// Completes a game session and updates the matching challengeProgress
    /// document atomically in a single Firestore transaction, so a partial
    /// failure never leaves a completed session pointing at stale progress.
    func completeGameSessionAndUpdateProgress(
        userId: String,
        sessionId: String,
        challengeId: String,
        answers: [GameAnswer],
        requiredScore: Int
    ) async throws -> (session: GameSession, progress: ChallengeProgress) {
        try FirebaseEnvironment.requireConfigured()
        let correct = answers.filter(\.isCorrect).count
        let total = answers.count
        let score = GameService.score(correct: correct, total: total)
        let stars = GameService.stars(forScore: score)
        let passed = score >= requiredScore
        let now = Date()

        let sessionRef = sessionsCollection(userId: userId).document(sessionId)
        let progressRef = db.collection("users").document(userId).collection("challengeProgress").document(challengeId)

        do {
            let progress = try await db.runTransaction { transaction -> ChallengeProgress in
                var progress: ChallengeProgress
                let progressSnapshot = try? transaction.getDocument(progressRef)
                if let progressSnapshot, progressSnapshot.exists,
                   let existing = try? progressSnapshot.data(as: ChallengeProgress.self) {
                    progress = existing
                    progress.attemptCount += 1
                    progress.bestScore = max(progress.bestScore, score)
                    progress.stars = max(progress.stars, stars)
                } else {
                    progress = ChallengeProgress(
                        status: .unlocked,
                        bestScore: score,
                        attemptCount: 1,
                        stars: stars,
                        unlockedAt: now,
                        completedAt: nil,
                        updatedAt: now
                    )
                }
                if passed {
                    progress.status = .completed
                    if progress.completedAt == nil {
                        progress.completedAt = now
                    }
                } else if progress.status != .completed {
                    progress.status = .inProgress
                }
                progress.updatedAt = now

                transaction.updateData([
                    "correctAnswers": correct,
                    "score": score,
                    "completedAt": Timestamp(date: now)
                ], forDocument: sessionRef)

                try transaction.setData(from: progress, forDocument: progressRef, merge: true)
                return progress
            }

            let session = try await sessionRef.getDocument(as: GameSession.self)
            return (session, progress)
        } catch {
            throw GameServiceError.writeFailed(error)
        }
    }

    func retrievePreviousSessionResults(
        userId: String,
        sessionId: String
    ) async throws -> (session: GameSession, answers: [GameAnswer]) {
        try FirebaseEnvironment.requireConfigured()
        let sessionRef = sessionsCollection(userId: userId).document(sessionId)
        do {
            let session = try await sessionRef.getDocument(as: GameSession.self)
            let answersSnapshot = try await sessionRef.collection("answers")
                .order(by: "answeredAt")
                .getDocuments()
            let answers = try answersSnapshot.documents.map { try $0.data(as: GameAnswer.self) }
            return (session, answers)
        } catch {
            throw GameServiceError.readFailed(error)
        }
    }
}

enum GameServiceError: LocalizedError {
    case readFailed(Error)
    case writeFailed(Error)

    var errorDescription: String? {
        switch self {
        case .readFailed(let error):
            return "Couldn't load game results: \(error.localizedDescription)"
        case .writeFailed(let error):
            return "Couldn't save your game progress: \(error.localizedDescription)"
        }
    }
}
