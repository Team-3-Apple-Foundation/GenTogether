
import SwiftUI

struct JourneyView: View {
    @Environment(GameProgress.self) private var progress
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var viewModel = JourneyViewModel()
    @State private var activeChallenge: GameChallenge?

    /// Maps the raw Firestore challenges into the lightweight display type
    /// GameView/ChallengeRow use. `fetchChallenges()` sorts by category, so
    /// this ordering — and therefore each challenge's `number` — is stable
    /// across launches, which matters because GameProgress persists
    /// completed challenges keyed by that number.
    private var challenges: [GameChallenge] {
        viewModel.challenges.enumerated().compactMap { index, challenge in
            guard let challengeId = challenge.id else { return nil }
            return GameChallenge(challengeId: challengeId, number: index + 1, title: challenge.category.displayName)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                GTHeader(
                    title: "Journey",
                    trailing: AnyView(
                        Button("Reset", systemImage: "arrow.counterclockwise") {
                            progress.resetAllProgress()
                        }
                    )
                )

                Group {
                    if viewModel.isLoading && viewModel.challenges.isEmpty {
                        ProgressView("Loading challenges…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let errorMessage = viewModel.errorMessage, viewModel.challenges.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "wifi.exclamationmark")
                                .font(.largeTitle)
                                .foregroundStyle(.orange)
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Button("Try Again") {
                                Task { await viewModel.load(userId: authViewModel.currentUserId) }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(20)
                    } else {
                        ScrollView {
                            VStack(spacing: 16) {
                                Text("Select a challenge below to play.")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                                    .padding(.bottom, 4)

                                ForEach(challenges) { challenge in
                                    let status = progress.status(forChallengeNumber: challenge.number)

                                    Button {
                                        activeChallenge = challenge
                                    } label: {
                                        ChallengeRow(challenge: challenge, status: status)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(status == .locked)
                                    .accessibilityLabel(
                                        "Challenge \(challenge.number),  \(challenge.title). \(status.label)."
                                    )
                                    .accessibilityHint(
                                        status == .locked
                                        ? "Finish the previous challenge to unlock this one."
                                        : "Opens this challenge."
                                    )
                                }
                            }
                            .padding(20)
                        }
                        .background(Color(.systemGroupedBackground))
                    }
                }
            }
            .fullScreenCover(item: $activeChallenge) { challenge in
                NavigationStack {
                    GameView(challenge: challenge, allChallenges: challenges)
                }
            }
            .task {
                await viewModel.load(userId: authViewModel.currentUserId)
            }
        }
    }
}

/// The three states a challenge can be in. An enum makes any fourth,
/// misspelled state impossible to write in the first place.
enum ChallengeStatus {
    case completed
    case upNext
    case locked

    var label: String {
        switch self {
        case .completed: "Completed"
        case .upNext: "Up next"
        case .locked: "Locked"
        }
    }

    var iconName: String {
        switch self {
        case .completed: "checkmark.circle.fill"
        case .upNext: "star.circle.fill"
        case .locked: "lock.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .completed: .green
        case .upNext: .orange
        case .locked: .gray
        }
    }
}

/// Lightweight display/navigation wrapper around a Firestore challenge.
/// GameView fetches the actual `Challenge` (with its rounds) itself given
/// `challengeId` — this type only carries what the Journey list and
/// GameProgress need before that fetch happens.
struct GameChallenge: Identifiable {
    let id = UUID()
    let challengeId: String
    let number: Int
    let title: String
}

struct ChallengeRow: View {
    let challenge: GameChallenge
    let status: ChallengeStatus

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: status.iconName)
                .font(.largeTitle)
                .foregroundStyle(status.color)

            VStack(alignment: .leading, spacing: 4) {
                Text("Challenge \(challenge.number): \(challenge.title)")
                    .font(.title3.weight(.semibold))

                Text(status.label)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.green, lineWidth: status == .upNext ? 3 : 0)
        )
    }
}

#Preview {
    JourneyView()
        .environment(GameProgress())

}
