
import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var preferencesViewModel = OnboardingViewModel()
    @State private var profile: UserProfile?
    @State private var showUpgradeSheet = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile?.displayName ?? authViewModel.displayName ?? "—")
                                .font(.headline)
                            Text(authViewModel.isAnonymous ? "Guest account" : "Registered account")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    NavigationLink {
                        HobbiesPreferenceView()
                    } label: {
                        HStack {
                            Text("Hobbies")
                            Spacer()
                            Text("Change")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if authViewModel.isAnonymous {
                    Section {
                        Button("Create a Permanent Account") { showUpgradeSheet = true }
                    } footer: {
                        Text("Upgrading keeps your existing progress — you'll just add an email and password.")
                    }
                }

                Section {
                    Button("Sign Out", role: .destructive) {
                        authViewModel.signOut()
                    }
                }
            }
            .navigationTitle("Profile")
            .task {
                await preferencesViewModel.loadExistingPreferences()
                await loadProfile()
            }
            .sheet(isPresented: $showUpgradeSheet) {
                UpgradeAccountView()
                    .environmentObject(authViewModel)
            }
        }
    }

    private func loadProfile() async {
        guard let userId = authViewModel.currentUserId else { return }
        profile = try? await UserService.shared.fetchCurrentUserProfile(userId: userId)
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
}
