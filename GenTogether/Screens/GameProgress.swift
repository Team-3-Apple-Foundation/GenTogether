//
//  GameProgress.swift
//  GenTogether
//
//  Tracks which challenges the player has passed. This is the single
//  source of truth for progress — every challenge's status is worked
//  out from it, never stored on the challenge itself.
//
//  Keyed by the Firestore challengeId (not a list position): the Journey
//  list can now be reordered — cross-category round robin, filtered by
//  preferredCategories — so "challenge number 5" doesn't reliably mean the
//  same challenge from one load to the next, but its challengeId always
//  does. Storage is also scoped per signed-in user (call `setCurrentUser`
//  whenever the uid changes), so one account never sees another's
//  completed challenges — this is still device-local only, not synced to
//  Firestore, so progress doesn't follow the player to another device.
//

import SwiftUI

/// A player must get at least this share of rounds right to pass.
private let passingShare = 0.6

@Observable
class GameProgress {

    private(set) var completedChallengeIds: Set<String> = []
    private var userId: String?

    private var storageKey: String {
        "completedChallengeIds.\(userId ?? "anonymous")"
    }

    /// Switches which account's local progress is loaded — mirrors the
    /// uid-scoping fix already applied to onboarding, so signing into a
    /// different account doesn't show the previous account's completed
    /// challenges. Call this whenever the signed-in uid changes.
    func setCurrentUser(_ userId: String?) {
        guard self.userId != userId else { return }
        self.userId = userId
        load()
    }

    /// Works out a challenge's status instead of storing it. `orderedIds`
    /// is the Journey list's current on-screen order (after category
    /// filtering and round-robin interleaving) — "up next" means the
    /// first challenge in *that* order that isn't completed yet, not a
    /// fixed number.
    func status(for challengeId: String, in orderedIds: [String]) -> ChallengeStatus {
        if completedChallengeIds.contains(challengeId) {
            return .completed
        }
        let nextPlayableId = orderedIds.first { !completedChallengeIds.contains($0) }
        return challengeId == nextPlayableId ? .upNext : .locked
    }

    /// How many correct answers are needed to pass a challenge of this length.
    /// Scales with length, so a 3-round challenge needs 2 rather than 3.
    static func passMark(outOf total: Int) -> Int {
        max(1, Int((Double(total) * passingShare).rounded(.up)))
    }

    /// Called when a game finishes. Only a passing score unlocks the next challenge.
    func recordResult(challengeId: String, score: Int, outOf total: Int) {
        guard score >= GameProgress.passMark(outOf: total) else { return }
        completedChallengeIds.insert(challengeId)
        save()
    }

    init() {
        load()
    }

    private func load() {
        let saved = UserDefaults.standard.array(forKey: storageKey) as? [String] ?? []
        completedChallengeIds = Set(saved)
    }

    private func save() {
        UserDefaults.standard.set(Array(completedChallengeIds), forKey: storageKey)
    }

    // development helper, wipes all progress so every challenge locks again
    func resetAllProgress() {
        completedChallengeIds = []
        save()
    }
}
