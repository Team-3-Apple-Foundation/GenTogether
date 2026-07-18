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
    @Published var aiFamiliarity: String = ""
    @Published var learningGoal: String = ""
    @Published var interests: Set<String> = []
    @Published var learningMinutes: Int = 10
    @Published var textSize: TextSizePreference = .standard

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var didComplete = false

    static let familiarityOptions = ["New to AI", "Somewhat familiar", "Very familiar"]
    static let goalOptions = ["Stay safe online", "Understand AI images", "Just curious"]
    static let interestOptions = ["Photography", "News", "Art", "Social media", "Family safety"]

    private let preferenceService: PreferenceService
    private let userIdProvider: @MainActor () -> String?

    init(
        preferenceService: PreferenceService? = nil,
        userIdProvider: (@MainActor () -> String?)? = nil
    ) {
        self.preferenceService = preferenceService ?? .shared
        self.userIdProvider = userIdProvider ?? { AuthService.shared.currentUser?.uid }
    }

    func loadExistingPreferences() async {
        guard let userId = userIdProvider() else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            if let existing = try await preferenceService.fetchOnboardingPreferences(userId: userId) {
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
            interests: Array(interests),
            learningMinutes: learningMinutes,
            textSize: textSize,
            onboardingCompleted: true,
            updatedAt: Date()
        )
        do {
            try await preferenceService.saveOnboardingPreferences(userId: userId, preferences: preferences)
            didComplete = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
