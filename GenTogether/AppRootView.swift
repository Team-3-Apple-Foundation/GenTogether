//
//  AppRootView.swift
//  GenTogether
//
//  Top-level router: authentication state decides between the sign-in
//  screen, onboarding, and the existing RootTabView. This is the view
//  GenTogetherApp actually shows — it does not replace RootTabView, it
//  gates access to it.
//

import SwiftUI

struct AppRootView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var onboardingViewModel = OnboardingViewModel()
    @State private var gameProgress = GameProgress()
    @State private var hasCheckedOnboarding = false

    var body: some View {
        Group {
            if !authViewModel.isAuthenticated {
                AuthView()
            } else if !hasCheckedOnboarding {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .task { await checkOnboarding() }
            } else if !onboardingViewModel.didComplete {
                OnboardingView(onboardingViewModel: onboardingViewModel)
            } else {
                RootTabView()
            }
        }
        .environmentObject(authViewModel)
        .environment(gameProgress)
        .onChange(of: authViewModel.currentUserId) { _, _ in
            hasCheckedOnboarding = false
        }
    }

    private func checkOnboarding() async {
        await onboardingViewModel.loadExistingPreferences()
        hasCheckedOnboarding = true
    }
}

#Preview {
    AppRootView()
}
