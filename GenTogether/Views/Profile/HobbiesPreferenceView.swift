//
//  HobbiesPreferenceView.swift
//  GenTogether
//
//  Reached by pushing from ProfileView's "Change" row. Lets the user
//  revisit which challenge categories they're interested in after
//  onboarding — same underlying data (preferredCategories) as onboarding's
//  interests step, but this is a settings screen, not a forced flow, so
//  it's its own lightweight view rather than reusing OnboardingView.
//

import SwiftUI

struct HobbiesPreferenceView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var viewModel = HobbiesPreferenceViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)
                } else {
                    card
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding(20)
        }
        .background(GTColor.background)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load(userId: authViewModel.currentUserId) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Hobbies")
                .font(.title.bold())
            Text("You can change anytime")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var card: some View {
        VStack(spacing: 0) {
            ForEach(Array(ChallengeCategory.allCases.enumerated()), id: \.element) { index, category in
                toggleRow(for: category)
                if index < ChallengeCategory.allCases.count - 1 {
                    Divider()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .gtCardBackground()
    }

    private func toggleRow(for category: ChallengeCategory) -> some View {
        Toggle(isOn: Binding(
            get: { viewModel.isSelected(category) },
            set: { viewModel.setCategory(category, isOn: $0, userId: authViewModel.currentUserId) }
        )) {
            Text(category.displayName)
                .font(.body)
        }
        .tint(GTColor.brand)
        .padding(.vertical, 12)
    }
}

#Preview {
    NavigationStack {
        HobbiesPreferenceView()
            .environmentObject(AuthViewModel())
    }
}
