//
//  JourneyViewModel.swift
//  GenTogether
//
//  Loads all challenges for the Journey screen. There's no per-user
//  progress tracking wired up for the challenges/rounds schema yet (the
//  old locked/unlocked/stars system was tied to the retired
//  challenges/questions schema) — every challenge is simply listed and
//  playable.
//

import Foundation
import Combine

@MainActor
final class JourneyViewModel: ObservableObject {
    @Published private(set) var challenges: [Challenge] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let challengeService: ChallengeService

    init(challengeService: ChallengeService? = nil) {
        self.challengeService = challengeService ?? .shared
    }

    var isEmpty: Bool { !isLoading && challenges.isEmpty }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            challenges = try await challengeService.fetchChallenges()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
