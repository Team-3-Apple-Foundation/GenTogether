//
//  LoggedInAccountView.swift
//  GenTogether
//
//  Pushed from ProfileView's "Manage Account" row when the signed-in
//  account is a real (non-anonymous) account — email/password or Google.
//  Split out from GuestAccountView because the two have genuinely
//  different fields: this one shows email, a change-password action,
//  sign-out, and account deletion, none of which apply to a guest.
//

import SwiftUI

struct LoggedInAccountView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(GameProgress.self) private var gameProgress
    @Environment(\.dismiss) private var dismiss

    @State private var profile: UserProfile?
    @State private var name = ""
    @State private var savedName = ""

    @State private var showDeleteConfirmation = false
    @State private var showReauthPasswordPrompt = false
    @State private var reauthPassword = ""

    var body: some View {
        VStack(spacing: 0) {
            GTHeader(title: "Profile", leading: AnyView(backButton))

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    avatar

                    if let infoMessage = authViewModel.infoMessage {
                        Text(infoMessage)
                            .font(.footnote)
                            .foregroundStyle(GTColor.success)
                    }

                    nameField
                    emailField
                    changePasswordButton
                    signOutButton
                    deleteAccountButton
                }
                .padding(20)
            }
            .background(GTColor.background)
        }
        .background(GTColor.background)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task { await loadProfile() }
        // Firebase refused account deletion because the sign-in session is
        // stale — AuthViewModel.deleteAccount sets this rather than a plain
        // error, so this screen can route straight into the right
        // reauthentication path instead of just showing an error banner.
        .onChange(of: authViewModel.needsReauthentication) { _, needsReauth in
            guard needsReauth else { return }
            if authViewModel.reauthProvider == .google {
                Task { await authViewModel.reauthenticateWithGoogleAndRetryDeletion(gameProgress: gameProgress) }
            } else {
                showReauthPasswordPrompt = true
            }
        }
        .confirmationDialog(
            "Delete your account?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Account", role: .destructive) {
                Task { await authViewModel.deleteAccount(gameProgress: gameProgress) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone. Your posts and comments stay visible, credited to \"[deleted user]\" — but your account and progress are permanently gone.")
        }
        .alert("Confirm your password", isPresented: $showReauthPasswordPrompt) {
            SecureField("Password", text: $reauthPassword)
            Button("Confirm") {
                let password = reauthPassword
                reauthPassword = ""
                Task {
                    await authViewModel.reauthenticateWithPasswordAndRetryDeletion(
                        password: password,
                        gameProgress: gameProgress
                    )
                }
            }
            Button("Cancel", role: .cancel) {
                reauthPassword = ""
                authViewModel.cancelReauthentication()
            }
        } message: {
            Text("For your security, please re-enter your password to confirm account deletion.")
        }
        .alert(
            "Something went wrong",
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

    private var avatar: some View {
        InitialsAvatar(name: savedName.isEmpty ? "M" : savedName, diameter: 72)
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
                } else if canSaveName {
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

    // Read-only by design — the user asked for display only, not editing.
    private var emailField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Email")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(authViewModel.email ?? profile?.email ?? "—")
                .foregroundStyle(.secondary)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.systemGray6))
                )
        }
    }

    // No password field, no dots — this sends a real Firebase password-
    // reset email rather than showing/collecting a password in-app.
    private var changePasswordButton: some View {
        Button {
            Task { await authViewModel.sendPasswordReset(email: authViewModel.email ?? profile?.email ?? "") }
        } label: {
            Text("Change Password")
                .font(.headline)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.bordered)
        .tint(GTColor.brand)
        .disabled(authViewModel.loadingAction == .passwordReset)
    }

    private var signOutButton: some View {
        Button {
            authViewModel.signOut()
        } label: {
            Text("Sign Out")
                .font(.headline)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, minHeight: 50)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.black, lineWidth: 1.5)
        )
    }

    private var deleteAccountButton: some View {
        Button {
            showDeleteConfirmation = true
        } label: {
            Group {
                if authViewModel.loadingAction == .deleteAccount {
                    ProgressView().tint(.white)
                } else {
                    Text("Delete Account")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 50)
        }
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .disabled(authViewModel.loadingAction == .deleteAccount)
    }

    // MARK: Logic

    private var canSaveName: Bool {
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
        let fallback = authViewModel.displayName ?? "Member"
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
        LoggedInAccountView()
            .environmentObject(AuthViewModel())
            .environment(GameProgress())
    }
}
