//
//  JourneyViewModel.swift
//  GenTogether
//
//  Loads all challenges for the Journey screen. There's no server-synced
//  per-user progress tracking wired up for the challenges/rounds schema
//  yet (the old locked/unlocked/stars system was tied to the retired
//  challenges/questions schema) — completion is tracked locally by
//  GameProgress instead (see completedChallengeIds below).
//
//  Loading happens in two parts, then one merge:
//   1. Challenges in whichever categories the user picked on the Interests
//      screen (`ChallengeService.fetchChallenges(categories:)`, a
//      server-side `whereField("category", in:)` query).
//   2. Any already-*completed* challenges that fall outside those
//      categories — so turning a category off in Interests never makes a
//      challenge the player already passed disappear from their list.
//  The merged set is then cross-category interleaved (one challenge per
//  category in turn, e.g. animals1, artAndCraft1, foods1, nature1,
//  animals2, ...) instead of running through every challenge in one
//  category before moving to the next. JourneyView builds both the
//  on-screen list order and GameView's "next challenge" order from this
//  same published array, so fixing the order here fixes it in both
//  places at once.
//
//  Because this whole two-part load re-runs from scratch every time
//  `load(userId:completedChallengeIds:)` is called, and RootTabView
//  recreates JourneyView (and this view model) fresh each time the
//  Journey tab is selected, coming back from Interests re-triggers both
//  parts — not just the category filter — automatically.
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

    /// - Parameter completedChallengeIds: from `GameProgress`, so a
    ///   challenge the player already passed stays visible even after its
    ///   category is turned off in Interests.
    func load(userId: String?, completedChallengeIds: Set<String>) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let preferredCategories = try await preferredCategories(for: userId)
            let byPreference = try await fetchByPreference(categories: preferredCategories)
            let stillCompleted = await completedChallengesOutsidePreferences(
                already: byPreference,
                completedChallengeIds: completedChallengeIds
            )
            challenges = Self.interleaved(byPreference + stillCompleted)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func preferredCategories(for userId: String?) async throws -> [ChallengeCategory]? {
        guard let userId else { return nil }
        return try await userService.fetchCurrentUserProfile(userId: userId)?.preferredCategories
    }

    /// Part 1: challenges in the user's picked categories. Falls back to
    /// every challenge when nothing's been picked yet (new account, or
    /// Interests never touched) — this same fallback is also what keeps an
    /// empty `preferredCategories` (however that happens) from ever
    /// reaching `fetchChallenges(categories:)`, which would otherwise build
    /// a `whereField("category", in: [])` query that Firestore rejects.
    private func fetchByPreference(categories: [ChallengeCategory]?) async throws -> [Challenge] {
        guard let categories, !categories.isEmpty else {
            return try await challengeService.fetchChallenges()
        }
        return try await challengeService.fetchChallenges(categories: categories)
    }

    /// Part 2: fetches, one at a time, any completed challenge that Part 1
    /// didn't already return (i.e. its category is no longer preferred).
    /// A completed id whose document no longer exists (or fails to load)
    /// is skipped rather than failing the whole screen — it just won't
    /// reappear in the list.
    private func completedChallengesOutsidePreferences(
        already fetched: [Challenge],
        completedChallengeIds: Set<String>
    ) async -> [Challenge] {
        let fetchedIds = Set(fetched.compactMap(\.id))
        let missingIds = completedChallengeIds.subtracting(fetchedIds)
        guard !missingIds.isEmpty else { return [] }

        var extra: [Challenge] = []
        for id in missingIds {
            if let challenge = try? await challengeService.fetchChallenge(id: id) {
                extra.append(challenge)
            }
        }
        return extra
    }

    /// Reorders `fetched` into cross-category round robin: one challenge
    /// from each category present in `fetched`, cycled in `categoryOrder`,
    /// repeating until every challenge has been placed.
    ///
    /// - "Active" categories are simply whichever categories `fetched`
    ///   actually contains — the caller (`load`) has already done all the
    ///   category *selection* (preference filtering plus merging back in
    ///   any completed-but-deselected challenges), so this only has to
    ///   decide the order, never which categories belong.
    /// - Once a category runs out, it's dropped from the rotation and the
    ///   remaining active categories keep alternating.
    /// - Order *within* a category is left exactly as `fetched` had it —
    ///   Firestore's own order, no extra sort field needed.
    private static func interleaved(_ fetched: [Challenge]) -> [Challenge] {
        var byCategory: [ChallengeCategory: [Challenge]] = [:]
        for challenge in fetched {
            byCategory[challenge.category, default: []].append(challenge)
        }

        let activeCategories = categoryOrder.filter { byCategory[$0] != nil }

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
