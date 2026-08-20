//
//  GuestAccountView.swift
//  GenTogether
//
//  Pushed from ProfileView's "Manage Account" row when the signed-in
//  account is still anonymous (a guest). Split out from LoggedInAccountView
//  because the two have genuinely different fields, not just one extra
//  button — a guest has no email/password to show and can't sign out
//  (there's no credential to sign back in with, per AuthViewModel.signOut's
//  own guard), while a registered account has no "create a permanent
//  account" upsell to show.
//

import SwiftUI

struct GuestAccountView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var profile: UserProfile?
    @State private var name = ""
    @State private var savedName = ""
    @State private var showUpgradeSheet = false

    var body: some View {
        VStack(spacing: 0) {
            GTHeader(title: "Profile", leading: AnyView(backButton))

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    avatarAndBadge
                    nameField
                    upgradeSection
                }
                .padding(20)
            }
            .background(GTColor.background)
        }
        .background(GTColor.background)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task { await loadProfile() }
        .sheet(isPresented: $showUpgradeSheet) {
            UpgradeAccountView()
                .environmentObject(authViewModel)
        }
        .alert(
            "Couldn't save",
            isPresented: Binding(
                get: { authViewModel.errorMessage != nil },
                set: { isPresented in if !isPresented { authViewModel.errorMessage = nil } }
            )
        ) {
            Button("OK") { authViewModel.errorMessage = nil }
        } message: {
            Text(authViewModel.errorMessage ?? "")
        }
    }

    // MARK: Sections

    private var avatarAndBadge: some View {
        VStack(spacing: 12) {
            InitialsAvatar(name: savedName.isEmpty ? "G" : savedName, diameter: 72)

            Text("Guest Account")
                .font(.caption.weight(.bold))
                .foregroundStyle(GTColor.tip)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(GTColor.tipSoft))
        }
        .frame(maxWidth: .infinity)
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Name")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                TextField("Your name", text: $name)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()

                if authViewModel.loadingAction == .profileUpdate {
                    ProgressView()
                } else if canSave {
                    Button("Save", action: saveName)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(GTColor.brand)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(.systemGray5), lineWidth: 1)
            )
        }
    }

    private var upgradeSection: some View {
        VStack(spacing: 10) {
            Button {
                showUpgradeSheet = true
            } label: {
                Text("Create a permanent account")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text("Creating a permanent account will keep your existing progress. You'll just add an email and password.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: Logic

    private var canSave: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != savedName
    }

    private func saveName() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            await authViewModel.updateDisplayName(trimmed)
            if authViewModel.errorMessage == nil {
                name = trimmed
                savedName = trimmed
            }
        }
    }

    private func loadProfile() async {
        // Shown immediately so the field isn't blank while the Firestore
        // fetch below is still in flight; corrected once it resolves.
        let fallback = authViewModel.displayName ?? "Guest"
        name = fallback
        savedName = fallback

        guard let userId = authViewModel.currentUserId else { return }
        profile = try? await UserService.shared.fetchCurrentUserProfile(userId: userId)
        if let fetchedName = profile?.displayName {
            name = fetchedName
            savedName = fetchedName
        }
    }

    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.black)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color(.systemGray5)))
        }
    }
}

#Preview {
    NavigationStack {
        GuestAccountView()
            .environmentObject(AuthViewModel())
    }
}
