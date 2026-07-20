//
//  OnboardingViewModel.swift
//  GenTogether
//
//  Drives the personalised onboarding flow: loads any previously saved
//  answers (so a returning-but-incomplete user doesn't restart from
//  scratch), and saves the final selections with onboardingCompleted = true.
//

import Foundation
import Combine
import FirebaseAuth

@MainActor
final class OnboardingViewModel: ObservableObject {

    // MARK: - Answers

    @Published var name: String = ""
    @Published var aiFamiliarity: String = ""
    @Published var learningGoal: String = ""
    @Published var interests: Set<String> = []
    @Published var learningMinutes: Int = 10
    @Published var textSize: TextSizePreference = .standard

    // MARK: - Flow state

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var didComplete = false

    // MARK: - Options

    static let familiarityOptions = [
        "Never heard about it",
        "I've heard about it",
        "Tried it once or twice",
        "I often use it"
    ]

    static let goalOptions = [
        "Keep my mind sharp",
        "Keep up with trends",
        "Just curious",
        "Be safe online"
    ]

    static let interestOptions = [
        "Animals",
        "Nature",
        "Arts and Craft",
        "Food"
    ]

    static let minuteOptions = [5, 10, 15, 20]

    // MARK: - Dependencies

    private let preferenceService: PreferenceService
    private let userIdProvider: @MainActor () -> String?

    init(
        preferenceService: PreferenceService? = nil,
        userIdProvider: (@MainActor () -> String?)? = nil
    ) {
        self.preferenceService = preferenceService ?? .shared
        self.userIdProvider = userIdProvider ?? { AuthService.shared.currentUser?.uid }
    }

    // MARK: - Load

    func loadExistingPreferences() async {
        guard let userId = userIdProvider() else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            if let existing = try await preferenceService.fetchOnboardingPreferences(userId: userId) {
                name = existing.name
                aiFamiliarity = existing.aiFamiliarity
                learningGoal = existing.learningGoal
                interests = Set(existing.interests)
                learningMinutes = existing.learningMinutes
                textSize = existing.textSize
                didComplete = existing.onboardingCompleted
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Save

    func completeOnboarding() async {
        guard let userId = userIdProvider() else {
            errorMessage = "You need to be signed in to save your preferences."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let preferences = UserPreferences(
            aiFamiliarity: aiFamiliarity,
            learningGoal: learningGoal,
            interests: Array(interests).sorted(),
            learningMinutes: learningMinutes,
            textSize: textSize,
            onboardingCompleted: true,
            updatedAt: Date(),
            name: name.trimmingCharacters(in: .whitespaces)
        )

        do {
            try await preferenceService.saveOnboardingPreferences(userId: userId, preferences: preferences)
            didComplete = true
        } catch {
            errorMessage = error.localizedDescription
        }
        
    }
}
