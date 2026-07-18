//
//  OnboardingView.swift
//  GenTogether
//
//  Personalised onboarding: familiarity with AI, learning goal, interests,
//  daily learning time, and reading text size. Saved to
//  users/{userId}/preferences/onboarding via OnboardingViewModel.
//

import SwiftUI

struct OnboardingView: View {
    @ObservedObject var onboardingViewModel: OnboardingViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("How familiar are you with AI?") {
                    Picker("AI familiarity", selection: $onboardingViewModel.aiFamiliarity) {
                        Text("Choose one").tag("")
                        ForEach(OnboardingViewModel.familiarityOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                }

                Section("What's your learning goal?") {
                    Picker("Learning goal", selection: $onboardingViewModel.learningGoal) {
                        Text("Choose one").tag("")
                        ForEach(OnboardingViewModel.goalOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                }

                Section("What are you interested in?") {
                    ForEach(OnboardingViewModel.interestOptions, id: \.self) { interest in
                        Toggle(interest, isOn: Binding(
                            get: { onboardingViewModel.interests.contains(interest) },
                            set: { isOn in
                                if isOn {
                                    onboardingViewModel.interests.insert(interest)
                                } else {
                                    onboardingViewModel.interests.remove(interest)
                                }
                            }
                        ))
                    }
                }

                Section("How many minutes a day would you like to learn?") {
                    Stepper(
                        "\(onboardingViewModel.learningMinutes) minutes",
                        value: $onboardingViewModel.learningMinutes,
                        in: 5...60,
                        step: 5
                    )
                }

                Section("Reading text size") {
                    Picker("Text size", selection: $onboardingViewModel.textSize) {
                        Text("Standard").tag(TextSizePreference.standard)
                        Text("Large").tag(TextSizePreference.large)
                        Text("Extra Large").tag(TextSizePreference.extraLarge)
                    }
                    .pickerStyle(.segmented)
                }

                if let errorMessage = onboardingViewModel.errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }

                Section {
                    Button {
                        Task { await onboardingViewModel.completeOnboarding() }
                    } label: {
                        Group {
                            if onboardingViewModel.isLoading {
                                ProgressView()
                            } else {
                                Text("Get Started")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(onboardingViewModel.isLoading)
                }
            }
            .navigationTitle("Welcome")
            .task { await onboardingViewModel.loadExistingPreferences() }
        }
    }
}

#Preview {
    OnboardingView(onboardingViewModel: OnboardingViewModel())
}
