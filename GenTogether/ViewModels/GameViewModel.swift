//
//  GameViewModel.swift
//  GenTogether
//
//  Drives a single play-through of a challenge's questions: loads
//  questions, starts a gameSession, records each answer, and completes the
//  session (updating challengeProgress) when the last question is
//  answered.
//

import Foundation
import Combine

@MainActor
final class GameViewModel: ObservableObject {
    let challenge: Challenge

    @Published private(set) var questions: [GameQuestion] = []
    @Published private(set) var currentIndex = 0
    @Published private(set) var answers: [GameAnswer] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var session: GameSession?
    @Published private(set) var isComplete = false
    @Published private(set) var finalProgress: ChallengeProgress?

    private let challengeService: ChallengeService
    private let gameService: GameService
    private var questionStartedAt = Date()

    init(challenge: Challenge, challengeService: ChallengeService? = nil, gameService: GameService? = nil) {
        self.challenge = challenge
        self.challengeService = challengeService ?? .shared
        self.gameService = gameService ?? .shared
    }

    var currentQuestion: GameQuestion? {
        questions.indices.contains(currentIndex) ? questions[currentIndex] : nil
    }

    var progressFraction: Double {
        guard !questions.isEmpty else { return 0 }
        return Double(currentIndex) / Double(questions.count)
    }

    func start(userId: String?) async {
        guard let userId else {
            errorMessage = "You need to be signed in to play."
            return
        }
        guard let challengeId = challenge.id else {
            errorMessage = "This challenge is missing its identifier."
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            questions = try await challengeService.fetchQuestions(challengeId: challengeId)
            guard !questions.isEmpty else {
                errorMessage = "This challenge doesn't have any questions yet. Check back soon."
                return
            }
            session = try await gameService.startGameSession(userId: userId, challengeId: challengeId, totalQuestions: questions.count)
            questionStartedAt = Date()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func submitAnswer(_ selected: SelectedAnswer, userId: String?) async {
        guard let userId, let sessionId = session?.id,
              let question = currentQuestion, let questionId = question.id else { return }

        let responseTime = Date().timeIntervalSince(questionStartedAt)
        let answer = GameAnswer(
            questionId: questionId,
            selectedAnswer: selected,
            isCorrect: selected == question.correctAnswer,
            responseTimeSeconds: responseTime,
            answeredAt: Date()
        )

        do {
            try await gameService.saveAnswer(userId: userId, sessionId: sessionId, answer: answer)
            answers.append(answer)
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        if currentIndex + 1 < questions.count {
            currentIndex += 1
            questionStartedAt = Date()
        } else {
            await finish(userId: userId)
        }
    }

    private func finish(userId: String) async {
        guard let sessionId = session?.id, let challengeId = challenge.id else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await gameService.completeGameSessionAndUpdateProgress(
                userId: userId,
                sessionId: sessionId,
                challengeId: challengeId,
                answers: answers,
                requiredScore: challenge.requiredScore
            )
            session = result.session
            finalProgress = result.progress
            isComplete = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
