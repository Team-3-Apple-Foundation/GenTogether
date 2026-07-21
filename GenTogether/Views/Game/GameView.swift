//
//  GameView.swift
//  GenTogether
//
//  Reached from JourneyView tapping a challenge. Fetches
//  challenges/{challengeId} via ChallengeService using the real id passed
//  in from navigation (never a hardcoded id), then shows one
//  ChallengeRound at a time. Media comes from ChallengeRound.mediaUrl — a
//  Supabase Storage public URL — rendered with RemoteMediaView, choosing
//  AsyncImage vs. AVKit's VideoPlayer based on ChallengeRound.isImage (the
//  authoritative field from Firestore, not a guess from the URL). Judging
//  is local-only right now; no scoring or progress is written back — the
//  challenges/questions-era progress system doesn't apply to this schema.
//

import SwiftUI

struct GameView: View {
    let challengeId: String

    @State private var challenge: Challenge?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var currentIndex = 0
    @State private var results: [Bool] = [] // true = judged correctly, in round order

    /// Which result row is open. `nil` means none are open.
    @State private var expandedResultIndex: Int?

    /// Bumped to force RemoteMediaView to re-attempt a load after Retry.
    @State private var mediaReloadToken = UUID()

    init(challengeId: String) {
        self.challengeId = challengeId
    }

    private var rounds: [ChallengeRound] {
        challenge?.rounds ?? []
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                ContentUnavailableView(errorMessage, systemImage: "exclamationmark.triangle")
            } else if currentIndex < rounds.count {
                questionView(rounds[currentIndex])
            } else {
                resultsView
            }
        }
        .padding(20)
        .navigationTitle(challenge?.category.displayName ?? "Challenge")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadChallenge() }
    }

    private func loadChallenge() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let fetched = try await ChallengeService.shared.fetchChallenge(id: challengeId)
            print("GameView: loaded challenge \(challengeId) — category: \(fetched.category.rawValue), rounds: \(fetched.rounds.count)")
            for round in fetched.rounds {
                print("  - \(round.id) [isImage: \(round.isImage)] isAI: \(round.isAI) url: \(round.mediaUrl)")
            }
            challenge = fetched
        } catch {
            print("GameView: failed to load challenge \(challengeId) — \(error)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - In-progress round

    private func questionView(_ round: ChallengeRound) -> some View {
        VStack(spacing: 24) {
            Text("Round \(currentIndex + 1) of \(rounds.count)")
                .font(.headline)
                .foregroundStyle(.secondary)

            RemoteMediaView(urlString: round.mediaUrl, isImage: round.isImage) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                mediaContainer { ProgressView() }
            } fallback: {
                mediaContainer {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundStyle(Color(.systemGray3))
                        Text("Couldn't load this media.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Button("Retry") { mediaReloadToken = UUID() }
                            .font(.footnote.weight(.semibold))
                    }
                }
            }
            .id(mediaReloadToken)
            .frame(height: 320)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            Text("Is this a real photo, or made by AI?")
                .font(.title2)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                answerButton(judgeAsAI: false, label: "Real photo", icon: "camera.fill", color: .blue, round: round)
                answerButton(judgeAsAI: true, label: "Made by AI", icon: "sparkles", color: .orange, round: round)
            }
        }
    }

    private func mediaContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground))
            .overlay { content() }
    }

    private func answerButton(judgeAsAI: Bool, label: String, icon: String, color: Color, round: ChallengeRound) -> some View {
        Button {
            results.append(judgeAsAI == round.isAI)
            mediaReloadToken = UUID()
            currentIndex += 1
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                Text(label)
                    .font(.title3.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 72)
        }
        .buttonStyle(.borderedProminent)
        .tint(color)
    }

    // MARK: - Results

    private var resultsView: some View {
        let score = results.filter { $0 }.count
        return ScrollView {
            VStack(spacing: 16) {
                Text("You got \(score) out of \(rounds.count)")
                    .font(.title.weight(.bold))

                Text("Tap any round to see the round id.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(spacing: 8) {
                    ForEach(Array(rounds.enumerated()), id: \.offset) { index, round in
                        resultRow(index: index, round: round)
                        Divider()
                    }
                }
            }
            .padding(20)
        }
    }

    private func resultRow(index: Int, round: ChallengeRound) -> some View {
        let isExpanded = expandedResultIndex == index
        let isCorrect = results.indices.contains(index) ? results[index] : false

        return VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    expandedResultIndex = isExpanded ? nil : index
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundStyle(isCorrect ? .green : .orange)

                    Text("Round \(index + 1)")
                        .foregroundStyle(.primary)

                    Text(isCorrect ? "Correct" : "Not quite")
                        .foregroundStyle(.secondary)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .font(.title3)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                HStack(alignment: .top, spacing: 10) {
                    Text("🦉")
                        .accessibilityHidden(true)
                    Text("round id: \(round.id) — isAI: \(round.isAI)")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, 4)
            }
        }
    }
}

#Preview {
    NavigationStack {
        GameView(challengeId: "preview-challenge-id")
    }
}
