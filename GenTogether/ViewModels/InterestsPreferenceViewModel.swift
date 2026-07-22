//
//  InterestsPreferenceViewModel.swift
//  GenTogether
//
//  Backs InterestsPreferenceView: loads users/{userId}.preferredCategories
//  and writes it back immediately on every toggle change — no Save button,
//  matching the design reference.
//

import Foundation
import Combine

@MainActor
final class InterestsPreferenceViewModel: ObservableObject {
    @Published private(set) var selectedCategories: Set<ChallengeCategory> = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let userService: UserService

    init(userService: UserService? = nil) {
        self.userService = userService ?? .shared
    }

    func load(userId: String?) async {
        guard let userId else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let profile = try await userService.fetchCurrentUserProfile(userId: userId)
            #if DEBUG
            print("[DIAG][Interests] loading for uid: \(userId)")
            print("[DIAG][Interests] path: users/\(userId), field: preferredCategories")
            print("[DIAG][Interests] preferredCategories raw value: \(String(describing: profile?.preferredCategories))")
            #endif
            selectedCategories = Set(profile?.preferredCategories ?? [])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func isSelected(_ category: ChallengeCategory) -> Bool {
        selectedCategories.contains(category)
    }

    /// True once only one category remains selected — the UI disables that
    /// category's toggle so it can't be turned off, since an empty
    /// `preferredCategories` is a semantically broken "no interests" state
    /// (not "show everything"), even though the read path tolerates it.
    func isOnlyRemaining(_ category: ChallengeCategory) -> Bool {
        selectedCategories == [category]
    }

    /// Updates local state immediately (so the toggle never visually
    /// reverts) and fires the Firestore write in the background. Refuses to
    /// drop the last remaining category — this mirrors the `.disabled`
    /// toggle in the view, but is enforced here too so this method stays
    /// safe to call from anywhere, not just that one toggle.
    func setCategory(_ category: ChallengeCategory, isOn: Bool, userId: String?) {
        if !isOn && isOnlyRemaining(category) {
            errorMessage = "At least one interest must stay selected."
            return
        }
        if isOn {
            selectedCategories.insert(category)
        } else {
            selectedCategories.remove(category)
        }
        guard let userId else { return }
        let categoriesToSave = Array(selectedCategories)
        Task {
            do {
                try await userService.updatePreferredCategories(userId: userId, categories: categoriesToSave)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
