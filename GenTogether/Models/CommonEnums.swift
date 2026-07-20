//
//  CommonEnums.swift
//  GenTogether
//
//  Controlled-vocabulary values shared across Firestore models. Raw String
//  enums keep Firestore documents human-readable while giving the app
//  compile-time safety instead of untyped strings.
//

import Foundation

/// Distinguishes anonymous (guest) sign-ins from permanent registered accounts.
/// Both share the same `users` collection; this field is the discriminator.
enum AccountType: String, Codable, Sendable {
    case guest
    case registered
}

/// Per-user progress state for a single challenge.
enum ChallengeStatus: String, Codable, Sendable {
    case locked
    case unlocked
    case inProgress
    case completed
}

/// Whether a game question's image is a real photo or AI-generated.
enum ImageType: String, Codable, Sendable {
    case real
    case aiGenerated
}

/// The answer a player can choose for a game question. Uses the same
/// vocabulary as `ImageType` so a submitted answer can be compared directly
/// against `GameQuestion.correctAnswer`.
enum SelectedAnswer: String, Codable, Sendable {
    case real
    case aiGenerated
}

/// User-selected reading text size, applied wherever the app already
/// supports Dynamic-Type-style scaling.
enum TextSizePreference: String, Codable, Sendable, CaseIterable {
    case standard
    case large
    case extraLarge
}
