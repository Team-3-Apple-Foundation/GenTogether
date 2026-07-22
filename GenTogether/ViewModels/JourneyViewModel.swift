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
//  `challenges` is also cross-category interleaved (one challenge per
//  category in turn, e.g. animals1, artAndCraft1, foods1, nature1,
//  animals2, ...) instead of the plain per-category grouping
//  `ChallengeService.fetchChallenges()` returns, so the Journey list
//  doesn't run through every challenge in one category before moving to
//  the next. JourneyView builds both the on-screen list order and
//  GameView's "next challenge" order from this same published array, so
//  fixing the order here fixes it in both places at once.
//

import Foundation
import Combine

@MainActor
final class JourneyViewModel: ObservableObject {
    @Published private(set) var challenges: [Challenge] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let challengeService: ChallengeService
    private let userService: UserService

    /// Fixed cycle order for interleaving categories — hardcoded for now;
    /// revisit if this ever needs to be configurable per-user or server-side.
    private static let categoryOrder: [ChallengeCategory] = [.animals, .arts, .foods, .natures]

    init(challengeService: ChallengeService? = nil, userService: UserService? = nil) {
        self.challengeService = challengeService ?? .shared
        self.userService = userService ?? .shared
    }

    var isEmpty: Bool { !isLoading && challenges.isEmpty }

    func load(userId: String?) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let fetched = try await challengeService.fetchChallenges()
            let preferredCategories = try await preferredCategories(for: userId)
            challenges = Self.interleaved(fetched, preferredCategories: preferredCategories)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func preferredCategories(for userId: String?) async throws -> [ChallengeCategory]? {
        guard let userId else { return nil }
        return try await userService.fetchCurrentUserProfile(userId: userId)?.preferredCategories
    }

    /// Reorders `fetched` into cross-category round robin: one challenge
    /// from each active category in `categoryOrder`, in turn, repeating
    /// until every challenge has been placed.
    ///
    /// - "Active" categories are whichever of `preferredCategories` the
    ///   user actually picked on the Hobbies screen — categories they
    ///   didn't pick are skipped entirely, not just deprioritized. If
    ///   `preferredCategories` is nil/empty (Hobbies never touched yet),
    ///   every category present in `fetched` is active instead, so the
    ///   list still shows something.
    /// - Once a category runs out, it's dropped from the rotation and the
    ///   remaining active categories keep alternating.
    /// - Order *within* a category is left exactly as `fetched` had it —
    ///   Firestore's own order, no extra sort field needed.
    private static func interleaved(_ fetched: [Challenge], preferredCategories: [ChallengeCategory]?) -> [Challenge] {
        var byCategory: [ChallengeCategory: [Challenge]] = [:]
        for challenge in fetched {
            byCategory[challenge.category, default: []].append(challenge)
        }

        let activeCategories: [ChallengeCategory]
        if let preferredCategories, !preferredCategories.isEmpty {
            activeCategories = categoryOrder.filter { preferredCategories.contains($0) }
        } else {
            activeCategories = categoryOrder.filter { byCategory[$0] != nil }
        }

        var cursors: [ChallengeCategory: Int] = [:]
        var result: [Challenge] = []

        while true {
            var addedAny = false
            for category in activeCategories {
                let items = byCategory[category] ?? []
                let index = cursors[category, default: 0]
                guard index < items.count else { continue }
                result.append(items[index])
                cursors[category] = index + 1
                addedAny = true
            }
            if !addedAny { break }
        }

        return result
    }
}
