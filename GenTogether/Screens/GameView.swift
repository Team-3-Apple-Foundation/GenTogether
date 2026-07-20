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

    /// Held as @State so "Next challenge" can swap it without pushing a new
    /// screen — the navigation stack stays two deep and back always means Journey.
    @State private var challenge: Challenge

    init(challenge: Challenge) {
        _challenge = State(initialValue: challenge)
    }

    private var rounds: [GameRound] {
        challenge.rounds
    }

    private var currentRound: GameRound {
        rounds[currentIndex]
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
    private var nextChallenge: Challenge? {
        Challenge.samples.first { $0.number == challenge.number + 1 }
    }

    var body: some View{
        VStack(spacing: 24){
            if currentIndex < rounds.count{
                Text("Round \(currentIndex + 1) of \(rounds.count)")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Image(currentRound.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .accessibilityLabel("Photo for round \(currentIndex + 1)")

                Text("Is this a real photo, or made by AI?")
                    .font(.title2)
                    .multilineTextAlignment(.center)

                HStack(spacing:12){
                    answerButton(for: .real)
                    answerButton(for: .ai)
                }
            }
            else {
                Text("You got \(score) out of \(rounds.count)")
                    .font(.title.weight(.bold))

                // Icon + word + colour, and never the word "failed" — a near
                // miss should read as an invitation, not a verdict.
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

                Text("Tap any round to see what gave it away.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(results) { result in
                            resultRow(for: result)
                            Divider()
                        }
                    }
                }

                // Only offered when there is a next challenge to go to.
                if let nextChallenge {
                    Button {
                        startGame(nextChallenge)
                    } label: {
                        Label("Next challenge", systemImage: "arrow.right.circle.fill")
                            .font(.title3.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 56)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!passed)
                    .accessibilityHint(
                        passed
                        ? "Starts \(nextChallenge.title)."
                        : "Locked. Score \(passMark) or more to unlock it."
                    )
                }

                // Whichever action makes sense is the prominent one, so the
                // screen always points at a single obvious next step.
                if passed {
                    playAgainButton.buttonStyle(.bordered)
                } else {
                    playAgainButton.buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(20)
        .navigationTitle(currentIndex < rounds.count ? challenge.title : "Your results")
        .navigationBarTitleDisplayMode(.inline)
        // Hides the automatic back chevron so ours is the only way out —
        // otherwise the system button would skip the confirmation.
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    leaveTapped()
                } label: {
                    Label("Home", systemImage: "chevron.left")
                }
            }
        }
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
                HStack(alignment: .top, spacing: 10) {
                    Text("🦉")
                        .accessibilityHidden(true)

                    Text(result.round.clue)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, 4)
            }
        }
    }

    private func answerButton(for answer: Answer) -> some View {
        Button{
            submit(answer)
        } label: {
            VStack(spacing: 6){
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
    
    /// The same button either way — only the style differs, so it lives here
    /// once rather than being written out twice in the body.
    private var playAgainButton: some View {
        Button {
            startGame(challenge)
        } label: {
            Label("Play again", systemImage: "arrow.clockwise")
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 56)
        }
    }

    /// Clears every trace of the last game so a new one starts fresh.
    /// One reset function, so new state can only be forgotten in one place.
    private func startGame(_ newChallenge: Challenge) {
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
        results.append(
            RoundResult(number: currentIndex + 1, round: currentRound, answer: answer)
        )
        currentIndex += 1

        // The last answer just landed, so the game is over. Report the score
        // and let GameProgress decide whether it unlocks anything.
        if currentIndex == rounds.count {
            progress.recordResult(
                challengeNumber: challenge.number,
                score: score,
                outOf: rounds.count
            )
        }
    }
}


enum Answer {
    case real
    case ai

    var label: String{
        switch self{
        case .real: "Real photo"
        case .ai: "Made by AI"
        }
    }

    var iconName: String{
        switch self{
        case .real: "camera.fill"
        case .ai: "sparkles"
        }
    }

    var color: Color{
        switch self{
        case .real: .blue
        case .ai: .orange
        }
    }
}


struct GameRound{
    let imageName: String
    let isAI: Bool
    let clue: String

    static let nature: [GameRound] = [
        GameRound(imageName: "nature1", isAI: true, clue: "..."),
        GameRound(imageName: "nature2", isAI: false, clue: "..."),
        GameRound(imageName: "nature3", isAI: true, clue: "..."),
        GameRound(imageName: "nature4", isAI: false, clue: "..."),
        GameRound(imageName: "nature5", isAI: true, clue: "...")
    ]
    
    static let animals: [GameRound] = [
        GameRound(imageName: "animal1", isAI: true, clue: "..."),
        GameRound(imageName: "animal2", isAI: false, clue: "..."),
        GameRound(imageName: "animal3", isAI: true, clue: "..."),
        GameRound(imageName: "animal4", isAI: false, clue: "..."),
        GameRound(imageName: "animal5", isAI: true, clue: "...")
    ]
    
    static let art: [GameRound] = [
        GameRound(imageName: "artCraft1", isAI: true, clue: "..."),
        GameRound(imageName: "artCraft2", isAI: false, clue: "..."),
        GameRound(imageName: "artCraft3", isAI: true, clue: "..."),
        GameRound(imageName: "artCraft4", isAI: false, clue: "..."),
        GameRound(imageName: "artCraft5", isAI: true, clue: "...")
    ]
    
    static let food: [GameRound] = [
        GameRound(imageName: "food1", isAI: true, clue: "..."),
        GameRound(imageName: "food2", isAI: false, clue: "..."),
        GameRound(imageName: "food3", isAI: true, clue: "..."),
        GameRound(imageName: "food4", isAI: false, clue: "..."),
        GameRound(imageName: "food5", isAI: true, clue: "...")
    ]
}


struct RoundResult: Identifiable {
    let id = UUID()
    let number: Int
    let round: GameRound
    let answer: Answer

    var isCorrect: Bool {
        (answer == .ai) == round.isAI
    }
}



#Preview {
    NavigationStack {
        GameView(challenge: Challenge.samples[0])
    }
    .environment(GameProgress())
}
