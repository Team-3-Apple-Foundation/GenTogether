//
//  GameResultsViewModel.swift
//  GenTogether
//
//  Reloads a previously saved game session and its answers, e.g. when a
//  results screen is opened later from a session history list rather than
//  right after finishing a game.
//

import Foundation
import Combine

@MainActor
final class GameResultsViewModel: ObservableObject {
    @Published private(set) var session: GameSession?
    @Published private(set) var answers: [GameAnswer] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let gameService: GameService

    init(gameService: GameService? = nil) {
        self.gameService = gameService ?? .shared
    }

    func load(userId: String, sessionId: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await gameService.retrievePreviousSessionResults(userId: userId, sessionId: sessionId)
            session = result.session
            answers = result.answers
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
