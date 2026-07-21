//
//  HobbiesPreferenceViewModel.swift
//  GenTogether
//
//  Backs HobbiesPreferenceView: loads users/{userId}.preferredCategories
//  and writes it back immediately on every toggle change — no Save button,
//  matching the design reference.
//

import Foundation
import Combine

@MainActor
final class HobbiesPreferenceViewModel: ObservableObject {
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
            print("[DIAG][Hobbies] loading for uid: \(userId)")
            print("[DIAG][Hobbies] path: users/\(userId), field: preferredCategories")
            print("[DIAG][Hobbies] preferredCategories raw value: \(String(describing: profile?.preferredCategories))")
            #endif
            selectedCategories = Set(profile?.preferredCategories ?? [])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func isSelected(_ category: ChallengeCategory) -> Bool {
        selectedCategories.contains(category)
    }

    /// Updates local state immediately (so the toggle never visually
    /// reverts) and fires the Firestore write in the background.
    func setCategory(_ category: ChallengeCategory, isOn: Bool, userId: String?) {
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
