//
//  JourneyViewModel.swift
//  GenTogether
//
//  Loads active challenges plus the current user's per-challenge progress,
//  and resolves each challenge's display status (locked / unlocked /
//  inProgress / completed) for the Journey screen.
//

import Foundation
import Combine

@MainActor
final class JourneyViewModel: ObservableObject {
    @Published private(set) var challenges: [Challenge] = []
    @Published private(set) var progressByChallengeId: [String: ChallengeProgress] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var isUsingFallbackData = false

    private let challengeService: ChallengeService

    init(challengeService: ChallengeService? = nil) {
        self.challengeService = challengeService ?? .shared
    }

    var isEmpty: Bool { !isLoading && challenges.isEmpty }

    func load(userId: String?) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let remoteChallenges = try await challengeService.fetchActiveChallenges()
            if remoteChallenges.isEmpty {
                challenges = LocalSampleData.challenges
                isUsingFallbackData = true
            } else {
                challenges = remoteChallenges
                isUsingFallbackData = false
            }

            if let userId {
                let progress = try await challengeService.fetchCurrentUserProgress(userId: userId)
                progressByChallengeId = Dictionary(uniqueKeysWithValues: progress.compactMap { entry in
                    entry.id.map { ($0, entry) }
                })
            }
        } catch {
            errorMessage = error.localizedDescription
            challenges = LocalSampleData.challenges
            isUsingFallbackData = true
        }
    }

    /// Falls back to "first challenge by order is unlocked, everything else
    /// is locked" when there's no saved progress document yet.
    func status(for challenge: Challenge) -> ChallengeStatus {
        if let id = challenge.id, let progress = progressByChallengeId[id] {
            return progress.status
        }
        let firstOrder = challenges.map(\.challengeOrder).min()
        return challenge.challengeOrder == firstOrder ? .unlocked : .locked
    }

    func progress(for challenge: Challenge) -> ChallengeProgress? {
        challenge.id.flatMap { progressByChallengeId[$0] }
    }
}
