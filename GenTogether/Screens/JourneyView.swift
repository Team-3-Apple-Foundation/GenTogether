
import SwiftUI

struct JourneyView: View {
    @Environment(GameProgress.self) private var progress
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var viewModel = JourneyViewModel()
    @State private var activeChallenge: GameChallenge?

    /// The challenge tapped but not yet confirmed — drives the bottom sheet.
    @State private var pendingChallenge: GameChallenge?

    /// Remembered across the sheet's dismissal so we launch the game only
    /// after the sheet has fully closed (avoids two pop-ups fighting).
    @State private var challengeToLaunch: GameChallenge?

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
                                Task { await viewModel.load(userId: authViewModel.currentUserId, completedChallengeIds: progress.completedChallengeIds) }
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
//                                    .foregroundStyle(.secondary)
                                    .foregroundStyle(.black)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                                    .padding(.bottom, 4)
                                    

                                let orderedIds = challenges.map(\.challengeId)
                                ForEach(challenges) { challenge in
                                    let status = progress.status(for: challenge.challengeId, in: orderedIds)

                                    Button {
                                        pendingChallenge = challenge
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
            .sheet(item: $pendingChallenge, onDismiss: {
                // Runs after the sheet has fully closed. If the player tapped
                // Play, this is where we actually launch the game.
                if let challengeToLaunch {
                    activeChallenge = challengeToLaunch
                    self.challengeToLaunch = nil
                }
            }) { challenge in
                ChallengeConfirmationSheet(
                    challenge: challenge,
                    onPlay: {
                        challengeToLaunch = challenge
                        pendingChallenge = nil
                    },
                    onCancel: {
                        pendingChallenge = nil
                    }
                )
                .presentationDetents([.height(260)])
            }
            .task {
                await viewModel.load(userId: authViewModel.currentUserId, completedChallengeIds: progress.completedChallengeIds)
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

    /// Card subtitle text — kept separate from `label` (used for the
    /// accessibility string above) since the two need slightly different
    /// wording/punctuation on the card itself.
    var cardSubtitle: String {
        switch self {
        case .completed: "Completed."
        case .upNext: "Unlocked"
        case .locked: "Locked."
        }
    }

    var iconName: String {
        switch self {
        case .completed: "star.fill"
        case .upNext: "lock.open.fill"
        case .locked: "lock.fill"
        }
    }

    /// The icon's circular background.
    var iconBackground: Color {
        switch self {
        case .completed: GTColor.success
        case .upNext: GTColor.brand
        case .locked: Color(.systemGray3)
        }
    }

    /// The icon glyph's own color, drawn on top of `iconBackground`.
    var iconForeground: Color {
        switch self {
        case .completed, .upNext: .black
        case .locked: .white
        }
    }

    var cardBackground: Color {
        switch self {
        case .completed: GTColor.successSoft
        case .upNext, .locked: Color(.systemBackground)
        }
    }

    var borderColor: Color {
        switch self {
        case .completed: GTColor.success
        case .upNext: GTColor.brand
        case .locked: Color(.systemGray5)
        }
    }

    /// Unlocked gets a heavier border so today's playable challenge stands
    /// out from the merely-completed or still-locked ones.
    var borderWidth: CGFloat {
        switch self {
        case .completed: 1.5
        case .upNext: 2.5
        case .locked: 1
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
            Circle()
                .fill(status.iconBackground)
                .frame(width: 52, height: 52)
                .overlay(
                    Image(systemName: status.iconName)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(status.iconForeground)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("Challenge \(challenge.number): \(challenge.title)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.black)

                Text(status.cardSubtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(status.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(status.borderColor, lineWidth: status.borderWidth)
        )
    }
}

/// The bottom sheet that slides up when a challenge is tapped, asking the
/// player to confirm before the game begins.
struct ChallengeConfirmationSheet: View {
    let challenge: GameChallenge
    let onPlay: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Challenge \(challenge.number): \(challenge.title)")
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)

            Text("Ready to play this challenge?")
                .font(.body)
                .foregroundStyle(.secondary)

            Button(action: onPlay) {
                Text("Play")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(GTColor.brand)

            Button("Not now", action: onCancel)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    JourneyView()
        .environment(GameProgress())

}
