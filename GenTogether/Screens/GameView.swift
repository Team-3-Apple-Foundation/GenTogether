//
//  GameView.swift
//  GenTogether
//
//  Created by Ameya More on 18/7/2026.
//

import SwiftUI

struct GameView: View {
    /// Closes this screen and returns to whichever screen pushed it.
    @Environment(\.dismiss) private var dismiss
    @Environment(GameProgress.self) private var progress

    @State private var currentIndex = 0
    @State private var results: [RoundResult] = []

    /// Which result row is open. `nil` means none are open.
    @State private var expandedResultID: UUID?

    @State private var showLeaveConfirmation = false

    /// The answer just given, waiting on the feedback card. `nil` = no card showing.
    @State private var pendingResult: RoundResult?

    /// Held as @State so "Next challenge" can swap it without pushing a new
    /// screen — the navigation stack stays two deep and back always means Journey.
    @State private var challenge: GameChallenge

    /// The rest of this journey's challenges, used to look up "next challenge".
    let allChallenges: [GameChallenge]

    /// The real challenge data (rounds with live media URLs) fetched from
    /// Firestore for `challenge.challengeId`. `nil` while loading or if the
    /// fetch hasn't run yet.
    @State private var loadedChallenge: Challenge?
    @State private var loadError: String?

    init(challenge: GameChallenge, allChallenges: [GameChallenge]) {
        _challenge = State(initialValue: challenge)
        self.allChallenges = allChallenges
    }

    private var rounds: [ChallengeRound] {
        loadedChallenge?.rounds ?? []
    }

    private var currentRound: ChallengeRound? {
        rounds.indices.contains(currentIndex) ? rounds[currentIndex] : nil
    }

    private var score: Int {
        results.filter(\.isCorrect).count
    }

    /// How many correct answers this challenge needs to unlock the next one.
    private var passMark: Int {
        GameProgress.passMark(outOf: rounds.count)
    }

    private var passed: Bool {
        score >= passMark
    }

    /// The challenge after this one, or nil if this is the last.
    private var nextChallenge: GameChallenge? {
        allChallenges.first { $0.number == challenge.number + 1 }
    }

    var body: some View {
        VStack(spacing: 0) {
            GTHeader(
                title: currentIndex < rounds.count ? "Guess it!" : "Results",
                leading: AnyView(
                    Button {
                        leaveTapped()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.black)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(Color(.systemGray5)))
                    }
                ),
                background: currentIndex < rounds.count ? .clear : GTColor.brand
            )

            Group {
                if let loadError {
                    failedLoadView(loadError)
                } else if loadedChallenge == nil {
                    ProgressView("Loading challenge…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if currentIndex < rounds.count {
                    gameRoundView
                } else {
                    resultsView
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .confirmationDialog(
            "Leave this game?",
            isPresented: $showLeaveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Leave game", role: .destructive) { dismiss() }
            Button("Keep playing", role: .cancel) { }
        } message: {
            Text("Your progress won't be saved.")
        }
        // Floats the instant-feedback card over the game whenever an answer
        // is waiting to be acknowledged with Continue.
        .overlay {
            if let pendingResult {
                feedbackCard(for: pendingResult)
                    .transition(.opacity)
            }
        }
        .task(id: challenge.challengeId) {
            await loadRounds()
        }
    }

    private func loadRounds() async {
        loadError = nil
        loadedChallenge = nil
        do {
            loadedChallenge = try await ChallengeService.shared.fetchChallenge(id: challenge.challengeId)
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func failedLoadView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("Couldn't load this challenge")
                .font(.title3.weight(.semibold))
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task { await loadRounds() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var gameRoundView: some View {
        if let currentRound {
            VStack(spacing: 24) {
                Text(challenge.title)
                    .font(.largeTitle.weight(.bold))

                Text("Round \(currentIndex + 1) of \(rounds.count)")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                RemoteMediaView(urlString: currentRound.mediaUrl) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } fallback: {
                    mediaFallback
                }
                .frame(maxWidth: .infinity)
                .frame(height: 320)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .accessibilityLabel("Photo for round \(currentIndex + 1)")

                Text("Is this a real photo, or made by AI?")
                    .font(.title2)
                    .multilineTextAlignment(.center)

                HStack(spacing: 12) {
                    answerButton(for: .real)
                    answerButton(for: .ai)
                }
            }
            .padding(20)
        }
    }

    private var mediaFallback: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Couldn't load media")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resultsView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 4) {
                        Text("You got \(score) out of \(rounds.count)")
                            .font(.title2.weight(.bold))

                        Label(
                            passed
                            ? "Challenge complete — the next one is unlocked."
                            : "You need \(passMark) correct to unlock the next challenge. Have another go?",
                            systemImage: passed ? "lock.open.fill" : "arrow.clockwise"
                        )
                        .font(.title3)
                        .foregroundStyle(passed ? .green : .orange)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: 8) {
                        ForEach(results) { result in
                            resultRow(for: result)
                            Divider()
                        }
                    }
                }
                .padding(20)
            }

            HStack(spacing: 8) {
                if let nextChallenge {
                    Button {
                        startGame(nextChallenge)
                    } label: {
                        Label("Next challenge", systemImage: "arrow.right.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!passed)
                    .accessibilityHint(
                        passed
                        ? "Starts \(nextChallenge.title)."
                        : "Locked. Score \(passMark) or more to unlock it."
                    )
                }

                if passed {
                    playAgainButton.buttonStyle(.bordered)
                } else {
                    playAgainButton.buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    private func resultRow(for result: RoundResult) -> some View {
        let isExpanded = (expandedResultID == result.id)

        return VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    expandedResultID = isExpanded ? nil : result.id
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: result.isCorrect ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundStyle(result.isCorrect ? .green : .orange)

                    Text("Round \(result.number)")
                        .foregroundStyle(.primary)

                    Text(result.isCorrect ? "Correct" : "Not quite")
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
            .accessibilityHint(isExpanded ? "Hides the explanation" : "Shows the explanation")

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    RemoteMediaView(urlString: result.round.mediaUrl) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        ProgressView()
                            .frame(width: 320, height: 320)
                    } fallback: {
                        mediaFallback
                            .frame(width: 320, height: 320)
                    }
                    .frame(width: 320, height: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityLabel("Photo from round \(result.number)")

                    Text("This image was \(result.round.isAI ? "made by AI" : "a real photo").")
                        .font(.headline)
                        .foregroundStyle(result.round.isAI ? .orange : .blue)

                    HStack(alignment: .top, spacing: 10) {
                        Text("🦉")
                            .accessibilityHidden(true)

                        Text(explanation(for: result.round))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func answerButton(for answer: Answer) -> some View {
        Button {
            submit(answer)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: answer.iconName)
                    .font(.title2)
                Text(answer.label)
                    .font(.title3.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 72)
        }
        .buttonStyle(.borderedProminent)
        .tint(answer.color)
    }

    /// The instant "Correct! / Not quite" card shown right after an answer.
    /// The deeper 🦉 explanation stays for the results screen — this is just the quick hit.
    private func feedbackCard(for result: RoundResult) -> some View {
        ZStack {
            // Dims the game behind the card so attention lands on the result.
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Right → green tick. Wrong → yellow lightbulb, framing the miss
                // as a helpful hint rather than a failure.
                Image(systemName: result.isCorrect ? "checkmark.circle.fill" : "lightbulb.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(result.isCorrect ? .green : .yellow)

                Text(result.isCorrect ? "Correct!" : "Not Quite")
                    .font(.title.weight(.bold))

                // Both cases just confirm what it was. The full explanation
                // is saved for the results screen at the end.
                Text("The image shown was \(result.round.isAI ? "AI generated" : "a real photo").")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                Button {
                    continueTapped()
                } label: {
                    Text("Continue")
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(.systemBackground))
            )
            .padding(40)
        }
    }

    /// The same button either way — only the style differs, so it lives here
    /// once rather than being written out twice in the body.
    private var playAgainButton: some View {
        Button {
            startGame(challenge)
        } label: {
            Label("Play again", systemImage: "arrow.clockwise")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    /// Clears every trace of the last game so a new one starts fresh.
    /// One reset function, so new state can only be forgotten in one place.
    private func startGame(_ newChallenge: GameChallenge) {
        challenge = newChallenge
        currentIndex = 0
        results = []
        expandedResultID = nil
    }

    /// Only interrupt with a confirmation if there's progress worth losing.
    private func leaveTapped() {
        let gameInProgress = currentIndex > 0 && currentIndex < rounds.count

        if gameInProgress {
            showLeaveConfirmation = true
        } else {
            dismiss()
        }
    }

    private func submit(_ answer: Answer) {
        guard let currentRound else { return }
        let result = RoundResult(number: currentIndex + 1, round: currentRound, answer: answer)
        results.append(result)

        // Don't advance yet — pop up the feedback card. Continue moves us on.
        withAnimation(.easeInOut(duration: 0.2)) {
            pendingResult = result
        }
    }

    /// Firestore rounds carry no hand-authored clue text (unlike the old
    /// hardcoded GameRound), so the explanation is generated from isAI.
    private func explanation(for round: ChallengeRound) -> String {
        round.isAI
            ? "This one was actually AI-generated — look closely next time!"
            : "This one was a real photo."
    }

    /// Dismisses the feedback card and moves to the next round. If that was the
    /// last round, the game is over, so report the score to GameProgress.
    private func continueTapped() {
        withAnimation(.easeInOut(duration: 0.2)) {
            pendingResult = nil
        }
        currentIndex += 1

        if currentIndex == rounds.count {
            progress.recordResult(
                challengeId: challenge.challengeId,
                score: score,
                outOf: rounds.count
            )
        }
    }
}


enum Answer {
    case real
    case ai

    var label: String {
        switch self {
        case .real: "Real photo"
        case .ai: "Made by AI"
        }
    }

    var iconName: String {
        switch self {
        case .real: "camera.fill"
        case .ai: "sparkles"
        }
    }

    var color: Color {
        switch self {
        case .real: .blue
        case .ai: .orange
        }
    }
}


struct RoundResult: Identifiable {
    let id = UUID()
    let number: Int
    let round: ChallengeRound
    let answer: Answer

    var isCorrect: Bool {
        (answer == .ai) == round.isAI
    }
}



#Preview {
    NavigationStack {
        GameView(
            challenge: GameChallenge(challengeId: "preview-challenge-id", number: 1, title: "Nature"),
            allChallenges: []
        )
    }
    .environment(GameProgress())
}
