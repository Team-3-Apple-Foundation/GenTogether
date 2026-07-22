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
    private let userService: UserService
    private let userIdProvider: @MainActor () -> String?
    private var resetCancellable: AnyCancellable?

    init(
        preferenceService: PreferenceService? = nil,
        userService: UserService? = nil,
        userIdProvider: (@MainActor () -> String?)? = nil
    ) {
        self.preferenceService = preferenceService ?? .shared
        self.userService = userService ?? .shared
        self.userIdProvider = userIdProvider ?? { AuthService.shared.currentUser?.uid }

        // UserService broadcasts this on sign-out so this view model — which
        // AppRootView keeps alive for the whole app session — never keeps
        // showing one account's answers after another account signs in.
        resetCancellable = NotificationCenter.default
            .publisher(for: .userSessionDidEnd)
            .sink { [weak self] _ in self?.resetToDefaults() }
    }

    // MARK: - Reset

    /// Puts every answer field back to its just-installed-the-app default.
    /// Called before every load AND on sign-out, so a brand-new account (or
    /// a fetch that finds no saved document) never inherits the previous
    /// account's leftover in-memory values.
    private func resetToDefaults() {
        name = ""
        aiFamiliarity = ""
        learningGoal = ""
        interests = []
        learningMinutes = 10
        didComplete = false
        errorMessage = nil
    }

    // MARK: - Load

    func loadExistingPreferences() async {
        resetToDefaults()
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
                didComplete = existing.onboardingCompleted
            }
            // else: no saved document for this uid (brand-new account) —
            // resetToDefaults() above already left every field blank, so
            // there's nothing left to do.
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
            onboardingCompleted: true,
            updatedAt: Date(),
            name: name.trimmingCharacters(in: .whitespaces)
        )

        #if DEBUG
        print("[DIAG][Onboarding] saving for uid: \(userId)")
        print("[DIAG][Onboarding] path: users/\(userId)/preferences/onboarding, field: interests")
        print("[DIAG][Onboarding] interests value being saved: \(preferences.interests)")
        #endif

        do {
            try await preferenceService.saveOnboardingPreferences(userId: userId, preferences: preferences)
            // Propagates the onboarding name into users/{userId}.displayName —
            // the field ProfileView and the rest of the app actually display.
            // Saving preferences is the primary result of onboarding, so a
            // failure here doesn't block completion; it's surfaced but
            // non-fatal, same as the guest-profile best-effort write.
            do {
                try await userService.updateDisplayName(userId: userId, displayName: preferences.name)
            } catch {
                errorMessage = "Saved your preferences, but couldn't save your name: \(error.localizedDescription)"
            }
            didComplete = true
        } catch {
            errorMessage = error.localizedDescription
        }

    }
}
