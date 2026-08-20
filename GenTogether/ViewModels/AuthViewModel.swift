//
//  AuthViewModel.swift
//  GenTogether
//
//  Drives the guest/sign-in/create-account screen and exposes the
//  authentication state that AppRootView uses to pick the initial route.
//

import Foundation
import Combine
import UIKit
import FirebaseAuth

/// Which authentication action is currently in flight, if any. Keeping this
/// as a single enum (rather than one Bool per button) means the Google,
/// guest, and email buttons never show each other's loading spinner, while
/// `run(as:)` still uses it to block two auth operations from overlapping.
enum AuthLoadingAction: Equatable {
    case none
    case email
    case google
    case guest
    case passwordReset
    case profileUpdate
    case deleteAccount
}

@MainActor
final class AuthViewModel: ObservableObject {
    @Published private(set) var loadingAction: AuthLoadingAction = .none
    @Published var errorMessage: String?
    @Published var infoMessage: String?
    @Published private(set) var isAuthenticated = false
    @Published private(set) var isAnonymous = false
    @Published private(set) var currentUserId: String?
    @Published private(set) var displayName: String?
    @Published private(set) var email: String?

    /// Set when a sensitive operation (currently just account deletion)
    /// was refused for having too old a session. The view watching this
    /// should prompt for the right credential — see `reauthProvider` for
    /// which kind — then call `reauthenticateAndRetryDeleteAccount`.
    @Published private(set) var needsReauthentication = false
    @Published private(set) var reauthProvider: AuthService.ReauthProvider?

    /// True while any authentication operation is running. Kept for call
    /// sites that don't need to distinguish which button triggered it.
    var isLoading: Bool { loadingAction != .none }

    private let authService: AuthService
    private let userService: UserService
    private let communityService: CommunityService
    private var cancellable: AnyCancellable?

    init(authService: AuthService? = nil, userService: UserService? = nil, communityService: CommunityService? = nil) {
        let authService = authService ?? .shared
        self.authService = authService
        self.userService = userService ?? .shared
        self.communityService = communityService ?? .shared
        cancellable = authService.$firebaseUser
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                self?.isAuthenticated = user != nil
                self?.isAnonymous = user?.isAnonymous ?? false
                self?.currentUserId = user?.uid
                self?.displayName = user?.displayName ?? (user?.isAnonymous == true ? "Guest" : nil)
                self?.email = user?.email
            }
    }

    /// "Continue as Guest". Firestore profile creation is treated as
    /// best-effort: if it fails, guest authentication has still succeeded
    /// (the Firebase Auth state listener already updated isAuthenticated),
    /// so we surface a profile-specific error instead of claiming sign-in
    /// itself failed.
    func continueAsGuest() async {
        guard loadingAction == .none else { return }
        loadingAction = .guest
        errorMessage = nil
        infoMessage = nil
        defer { loadingAction = .none }

        do {
            let user = try await authService.continueAsGuest()
            do {
                try await userService.createUserProfileIfNeeded(
                    userId: user.uid,
                    displayName: "Guest",
                    email: nil,
                    accountType: .guest
                )
                try await userService.updateLastLogin(userId: user.uid)
            } catch {
                errorMessage = "Guest sign-in succeeded, but the guest profile could not be saved: \(error.localizedDescription)"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createAccount(email: String, password: String, displayName: String) async {
        await run(as: .email) {
            let user = try await self.authService.createAccount(email: email, password: password, displayName: displayName)
            try await self.userService.createUserProfileIfNeeded(
                userId: user.uid,
                displayName: displayName,
                email: email,
                accountType: .registered
            )
        }
    }

    func signIn(email: String, password: String) async {
        await run(as: .email) {
            let user = try await self.authService.signIn(email: email, password: password)
            try await self.userService.updateLastLogin(userId: user.uid)
        }
    }

    /// Sends a password-reset email. Deliberately shows the same
    /// confirmation whether or not the email belongs to a real account, so
    /// the screen never reveals which addresses are registered. A genuinely
    /// malformed email still surfaces an error so the user can fix a typo.
    func sendPasswordReset(email: String) async {
        guard loadingAction == .none else { return }

        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Enter your email above, then tap Forgot password."
            return
        }

        loadingAction = .passwordReset
        errorMessage = nil
        infoMessage = nil
        defer { loadingAction = .none }

        do {
            try await authService.sendPasswordReset(email: trimmed)
        } catch {
            // Swallow "user not found" so we don't reveal account existence;
            // any other error (e.g. malformed address) is worth showing.
            let code = AuthErrorCode(rawValue: (error as NSError).code)
            if code != .userNotFound {
                errorMessage = error.localizedDescription
                return
            }
        }

        infoMessage = "If that email is registered, we've sent a link to reset your password. Please check your inbox."
    }

    /// Upgrades the current guest session to a registered account,
    /// preserving the Firebase UID and every Firestore document already
    /// written under it.
    func upgradeGuestAccount(email: String, password: String, displayName: String) async {
        await run(as: .email) {
            let user = try await self.authService.linkAnonymousAccount(email: email, password: password, displayName: displayName)
            try await self.userService.updateDisplayName(userId: user.uid, displayName: displayName)
        }
    }

    /// Saves a new display name to both Firestore (`users/{uid}.displayName`,
    /// what the app reads back on future launches) and Firebase Auth's own
    /// `user.displayName` (what this view model's own `displayName`
    /// actually reflects live — see `AuthService.updateCurrentUserDisplayName`).
    /// Skipping either half would leave the two out of sync until the next
    /// full relaunch.
    func updateDisplayName(_ displayName: String) async {
        await run(as: .profileUpdate) {
            guard let userId = self.currentUserId else { return }
            try await self.userService.updateDisplayName(userId: userId, displayName: displayName)
            try await self.authService.updateCurrentUserDisplayName(displayName)
        }
    }

    func signInWithGoogle() async {
        await run(as: .google) {
            guard let presenter = Self.topViewController() else {
                throw AuthServiceError.googleSignInFailed(GoogleSignInError.missingPresentingViewController)
            }
            let user = try await self.authService.signInWithGoogle(presenting: presenter)
            try await self.userService.createUserProfileIfNeeded(
                userId: user.uid,
                displayName: user.displayName ?? "Member",
                email: user.email,
                accountType: .registered
            )
            try await self.userService.updateLastLogin(userId: user.uid)
        }
    }

    /// GIDSignIn needs a UIViewController to present its web/browser sign-in
    /// sheet from — SwiftUI has no direct handle to one, so this walks the
    /// active window scene's key window down to whatever's on top.
    private static func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
            let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController else {
            return nil
        }
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }

    func signOut() {
        do {
            try authService.signOut()
            userService.resetLocalUserState()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Account deletion

    /// Permanently deletes the signed-in account: reassigns their community
    /// posts/comments to "[deleted user]" (content, likes, and other
    /// users' replies are left untouched), deletes their Firestore user
    /// document and local game progress, then deletes the Firebase Auth
    /// user itself — in that order, since the Firestore steps need
    /// `request.auth` to still resolve to this uid.
    ///
    /// `gameProgress` is passed in rather than held as a stored dependency
    /// because it's a separate `@Environment` object scoped to the view
    /// hierarchy, not something AuthViewModel otherwise needs — this keeps
    /// the coupling to just this one call site.
    func deleteAccount(gameProgress: GameProgress) async {
        guard loadingAction == .none, let userId = currentUserId else { return }
        loadingAction = .deleteAccount
        errorMessage = nil
        infoMessage = nil
        needsReauthentication = false

        #if DEBUG
        print("[AuthViewModel] deleteAccount — step 1/4: anonymizing community content for uid \(userId)")
        #endif

        do {
            try await communityService.anonymizeContent(forDeletedUserId: userId)

            #if DEBUG
            print("[AuthViewModel] deleteAccount — step 2/4: deleting users/\(userId)")
            #endif
            try await userService.deleteUserDocument(userId: userId)

            #if DEBUG
            print("[AuthViewModel] deleteAccount — step 3/4: clearing local game progress for uid \(userId)")
            #endif
            gameProgress.clearProgress(forUserId: userId)

            #if DEBUG
            print("[AuthViewModel] deleteAccount — step 4/4: deleting Firebase Auth user \(userId)")
            #endif
            try await authService.deleteCurrentUser()

            userService.resetLocalUserState()
            #if DEBUG
            print("[AuthViewModel] deleteAccount — all steps completed for uid \(userId)")
            #endif
        } catch AuthServiceError.reauthenticationRequired {
            // Everything above this point is safe to redo — reassigning
            // already-"[deleted user]" content, deleting an
            // already-deleted Firestore doc, and clearing already-empty
            // local progress are all no-ops — so the retry after
            // reauthenticating just runs this whole function again rather
            // than needing to resume partway through.
            reauthProvider = authService.currentUserReauthProvider()
            needsReauthentication = true
        } catch {
            #if DEBUG
            print("[AuthViewModel] deleteAccount FAILED for uid \(userId) — the step above this line in the console is the one that threw. Underlying error: \(error)")
            #endif
            errorMessage = error.localizedDescription
        }

        loadingAction = .none
    }

    /// Call after the view has re-collected the user's password in
    /// response to `needsReauthentication` (with `reauthProvider == .password`).
    func reauthenticateWithPasswordAndRetryDeletion(password: String, gameProgress: GameProgress) async {
        guard let email else {
            errorMessage = "Couldn't find your email to confirm your password."
            return
        }
        do {
            try await authService.reauthenticateWithPassword(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        needsReauthentication = false
        await deleteAccount(gameProgress: gameProgress)
    }

    /// Call in response to `needsReauthentication` when `reauthProvider == .google`
    /// — re-triggers the Google sign-in sheet rather than collecting a password.
    func reauthenticateWithGoogleAndRetryDeletion(gameProgress: GameProgress) async {
        guard let presenter = Self.topViewController() else {
            errorMessage = "Couldn't find a screen to present Google Sign-In from."
            return
        }
        do {
            try await authService.reauthenticateWithGoogle(presenting: presenter)
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        needsReauthentication = false
        await deleteAccount(gameProgress: gameProgress)
    }

    /// The user backed out of the reauthentication prompt — leaves the
    /// account exactly as it was; nothing was deleted yet.
    func cancelReauthentication() {
        needsReauthentication = false
        reauthProvider = nil
    }

    private func run(as action: AuthLoadingAction, _ operation: @escaping () async throws -> Void) async {
        guard loadingAction == .none else { return }
        loadingAction = action
        errorMessage = nil
        infoMessage = nil
        do {
            try await operation()
        } catch {
            errorMessage = error.localizedDescription
        }
        loadingAction = .none
    }
}
