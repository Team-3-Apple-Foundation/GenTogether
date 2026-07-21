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

    init(challenge: GameChallenge) {
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
    private var nextChallenge: GameChallenge? {
        GameChallenge.samples.first { $0.number == challenge.number + 1 }
    }

    var body: some View {
        Group {
            if currentIndex < rounds.count {
                VStack(spacing: 24) {
                    Text(challenge.title)
                        .font(.largeTitle.weight(.bold))

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

                    HStack(spacing: 12) {
                        answerButton(for: .real)
                        answerButton(for: .ai)
                    }
                }
                .padding(20)
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        Text("You got \(score) out of \(rounds.count)")
                            .font(.title.weight(.bold))

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

                        VStack(spacing: 8) {
                            ForEach(results) { result in
                                resultRow(for: result)
                                Divider()
                            }
                        }

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

                        if passed {
                            playAgainButton.buttonStyle(.bordered)
                        } else {
                            playAgainButton.buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle(currentIndex < rounds.count ? "" : "Your results")
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
        // Floats the instant-feedback card over the game whenever an answer
        // is waiting to be acknowledged with Continue.
        .overlay {
            if let pendingResult {
                feedbackCard(for: pendingResult)
                    .transition(.opacity)
            }
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
                    Image(result.round.imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 140, height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accessibilityLabel("Photo from round \(result.number)")

                    Text("This image was \(result.round.isAI ? "made by AI" : "a real photo").")
                        .font(.headline)
                        .foregroundStyle(result.round.isAI ? .orange : .blue)

                    HStack(alignment: .top, spacing: 10) {
                        Text("🦉")
                            .accessibilityHidden(true)

                        Text(result.round.clue)
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
    /// The deeper 🦉 clue stays for the results screen — this is just the quick hit.
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
                // (round.clue) is saved for the results screen at the end.
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
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 56)
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
        let result = RoundResult(number: currentIndex + 1, round: currentRound, answer: answer)
        results.append(result)

        // Don't advance yet — pop up the feedback card. Continue moves us on.
        withAnimation(.easeInOut(duration: 0.2)) {
            pendingResult = result
        }
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


struct GameRound {
    let imageName: String
    let isAI: Bool
    let clue: String

    static let nature: [GameRound] = [
        GameRound(
            imageName: "nature1",
            isAI: true,
            clue: "Flowers are not identical which makes it realistic. Sizes vary, some are wilted, and dirt patches can be seen among the field."),
        GameRound(imageName: "nature2", isAI: false, clue: "Look close at the waterfall mist. It is messy and uneven which aligns with how cameras capture motion. AI often generates overly smooth textures and inconsistent reflections for water. Also the distance and scale between the people are realistic. "),
        GameRound(imageName: "nature3", isAI: true, clue: "Plants are growing in natural and imperfect shapes. Also the rusty texture of the cart and table are consistent. AI often tries to make plants look perfect with symmetrical leaves or unrealistic colours."),
        GameRound(imageName: "nature4", isAI: false, clue: "The person’s shirt has wrinkles and the pattern on it is consistent. Also lighting and shadow align with how the person is positioned."),
        GameRound(imageName: "nature5", isAI: true, clue: "The people are not identical in the photo and captured in candid poses. The cherry blossom trees are growing in natural and imperfect shapes.")
    ]

    static let animals: [GameRound] = [
        GameRound(imageName: "animal1", isAI: true, clue: "The photo captures fine details such as each individual whisker, correct amount of paws and ears. The camera focuses sharply on the kitten and blurs the background. AI cannot capture these fine details easily."),
        GameRound(imageName: "animal2", isAI: false, clue: "The background captures fine details such as a shelf of threads and a person. The cat is in a candid pose with a consistent lighting, correct amount of paws and ears. AI cannot capture these fine details easily."),
        GameRound(imageName: "animal3", isAI: true, clue: "The photo captures a soft and natural sunlight which is accurately reflected on the cat’s fur. The background has a realistic blur which matches with how the camera is focused on the cat."),
        GameRound(imageName: "animal4", isAI: false, clue: "This is real because you can see the individual strands of the dog fur and their natural details such as teeth, paws, and different patterns. Also look at the man’s hand, it is positioned naturally and has exactly five fingers."),
        GameRound(imageName: "animal5", isAI: true, clue: "The chicken feathers are slightly ruffled and have two legs which are natural. The image captures fine details of the man such as hand veins and wrinkles on his clothes which AI struggles to generate.")
    ]

    static let art: [GameRound] = [
        GameRound(imageName: "artCraft1", isAI: true, clue: "This is real because you can see the individual loops of yarn on the needle. Also the person’s fingers show wrinkles and do not look distorted. These fine details are hard for AI to correctly copy."),
        GameRound(imageName: "artCraft2", isAI: false, clue: "The bags vary in shape and size, but each pattern looks complete and not jumbled. The colours are bright and consistent which feel natural that it is a collection of bags at a market stall."),
        GameRound(imageName: "artCraft3", isAI: true, clue: "Take a close look at the elderly couple, there are natural wrinkles on their hands and faces. The amount of fingers are clear and the facial expression matches their body language. Lastly, the table scattered with brushes and paint textures are realistic."),
        GameRound(imageName: "artCraft4", isAI: false, clue: "The tree branches and dots are uneven and its smudged texture makes it clear that it was painted. Other small details that make it real is the canvas being hollow at the back and texture of the person’s hair."),
        GameRound(imageName: "artCraft5", isAI: true, clue: "This is real because the photo shows an uneven texture of paint strokes and the paint palette colours align with the artwork. The photo accurately captures a person in the middle of painting.")
    ]

    static let food: [GameRound] = [
        GameRound(imageName: "food1", isAI: true, clue: "This is real because the fold of the pasta ribbons are uneven and the sauce appears messy. The fingers on the hand are clearly visible. Lastly, the background shows how the dish was cooked at a home kitchen which makes the photo feel authentic."),
        GameRound(imageName: "food2", isAI: false, clue: "The photo shows imperfections such as each bread roll has sesame seeds randomly scattered, sizes vary, and browned parts. The lighting is a warm palette which matches how the bread is in an oven tray. These details make it real."),
        GameRound(imageName: "food3", isAI: true, clue: "Take a close look. You can see natural steam and juices around the vegetables, button cubes melting at various rates, and the texture of a shiny pan. These details naturally capture how ingredients are stir fried."),
        GameRound(imageName: "food4", isAI: false, clue: "The dumplings wrappings are not identical. Each has different folds, sesame seeds scattered, and the wrinkled texture is clearly visible. The lighting captures the ceramic plate texture and the marble pattern is consistent. These details make the photo real."),
        GameRound(imageName: "food5", isAI: true, clue: "The uneven light and shadows are reflected on both the table and fruits. Blemishes, fuzzy, and shiny textures are clearly visible which are natural features of fruit. All these details make the photo real.")
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
        GameView(challenge: GameChallenge.samples[0])
    }
    .environment(GameProgress())
}
