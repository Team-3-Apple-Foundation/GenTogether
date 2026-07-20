//
//  GameProgress.swift
//  GenTogether
//
//  Tracks which challenges the player has passed. This is the single
//  source of truth for progress — every challenge's status is worked
//  out from it, never stored on the challenge itself.
//

import SwiftUI

/// A player must get at least this share of rounds right to pass.
private let passingShare = 0.6

@Observable
class GameProgress {
    
    private let storageKey = "completedChalleNumbers"
    /// Challenge numbers the player has passed.
    /// `private(set)` means anyone can read it, but only this class can change it.
    private(set) var completedNumbers: Set<Int> = [] {
        didSet { save() }
    }

    /// The lowest challenge number not yet passed — the one that's playable.
    private var nextPlayableNumber: Int {
        var candidate = 1
        while completedNumbers.contains(candidate) {
            candidate += 1
        }
        return candidate
    }

    /// Works out a challenge's status instead of storing it.
    func status(forChallengeNumber number: Int) -> ChallengeStatus {
        if completedNumbers.contains(number) {
            return .completed
        } else if number == nextPlayableNumber {
            return .upNext
        } else {
            return .locked
        }
    }

    /// How many correct answers are needed to pass a challenge of this length.
    /// Scales with length, so a 3-round challenge needs 2 rather than 3.
    static func passMark(outOf total: Int) -> Int {
        max(1, Int((Double(total) * passingShare).rounded(.up)))
    }

    /// Called when a game finishes. Only a passing score unlocks the next challenge.
    func recordResult(challengeNumber: Int, score: Int, outOf total: Int) {
        if score >= GameProgress.passMark(outOf: total) {
            completedNumbers.insert(challengeNumber)
        }
    }
    
    init() {
        let saved = UserDefaults.standard.array(forKey: storageKey) as? [Int] ?? []
        completedNumbers = Set(saved)
    }
    
    private func save(){
        UserDefaults.standard.set(Array(completedNumbers), forKey: storageKey)
    }
    
    // development helper, wipes all progress so every challenge locks again
    func resetAllProgress(){
        completedNumbers = []
    }
}
