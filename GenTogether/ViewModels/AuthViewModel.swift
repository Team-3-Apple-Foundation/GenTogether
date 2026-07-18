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

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var isAuthenticated = false
    @Published private(set) var isAnonymous = false
    @Published private(set) var currentUserId: String?
    @Published private(set) var displayName: String?

    private let authService: AuthService
    private let userService: UserService
    private var cancellable: AnyCancellable?

    init(authService: AuthService? = nil, userService: UserService? = nil) {
        let authService = authService ?? .shared
        self.authService = authService
        self.userService = userService ?? .shared
        cancellable = authService.$firebaseUser
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                self?.isAuthenticated = user != nil
                self?.isAnonymous = user?.isAnonymous ?? false
                self?.currentUserId = user?.uid
                self?.displayName = user?.displayName ?? (user?.isAnonymous == true ? "Guest" : nil)
            }
    }

    func continueAsGuest() async {
        await run {
            let user = try await self.authService.continueAsGuest()
            try await self.userService.createUserProfileIfNeeded(
                userId: user.uid,
                displayName: "Guest",
                email: nil,
                accountType: .guest
            )
            try await self.userService.updateLastLogin(userId: user.uid)
        }
    }

    func createAccount(email: String, password: String, displayName: String) async {
        await run {
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
        await run {
            let user = try await self.authService.signIn(email: email, password: password)
            try await self.userService.updateLastLogin(userId: user.uid)
        }
    }

    /// Upgrades the current guest session to a registered account,
    /// preserving the Firebase UID and every Firestore document already
    /// written under it.
    func upgradeGuestAccount(email: String, password: String, displayName: String) async {
        await run {
            let user = try await self.authService.linkAnonymousAccount(email: email, password: password, displayName: displayName)
            try await self.userService.updateDisplayName(userId: user.uid, displayName: displayName)
        }
    }

    func signInWithGoogle() async {
        await run {
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

    private func run(_ operation: @escaping () async throws -> Void) async {
        isLoading = true
        errorMessage = nil
        do {
            try await operation()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
