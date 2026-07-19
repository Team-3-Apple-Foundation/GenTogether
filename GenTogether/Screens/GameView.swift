//
//  GameView.swift
//  GenTogether
//
//  Created by Ameya More on 18/7/2026.
//

import SwiftUI



struct GameView: View {
    @State private var currentIndex = 0
    @State private var results: [RoundResult] = []

    /// Which result row is open. `nil` means none are open.
    @State private var expandedResultID: UUID?

    private let rounds = GameRound.samples

    private var currentRound: GameRound {
        rounds[currentIndex]
    }

    private var score: Int {
        results.filter(\.isCorrect).count
    }
    
    var body: some View{
        VStack(spacing: 24){
            if currentIndex < rounds.count{
                Text("Round \(currentIndex + 1) of \(rounds.count)")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .frame(height: 320)
                    .overlay{
                        Image(systemName: "photo")
                            .font(.system(size: 64))
                            .foregroundStyle(Color(.systemGray3))
                    }

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
            }
        }
        .padding(20)
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
    
    private func submit(_ answer: Answer) {
        results.append(
            RoundResult(number: currentIndex + 1, round: currentRound, answer: answer)
        )
        currentIndex += 1
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

    static let samples: [GameRound] = [
        GameRound(imageName: "round1", isAI: true,
                  clue: "Look at the trees at the back. The leaves blur into mush. Real cameras keep that detail."),
        GameRound(imageName: "round2", isAI: false,
                  clue: "Every shadow falls the same way, which is a good sign of a real photograph."),
        GameRound(imageName: "round3", isAI: true,
                  clue: "Count the fingers. AI struggles with hands more than almost anything else."),
        GameRound(imageName: "round4", isAI: false,
                  clue: "The writing on the sign is sharp and readable. AI usually garbles small text."),
        GameRound(imageName: "round5", isAI: true,
                  clue: "The pattern repeats too perfectly — real fabric folds and breaks up patterns.")
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
    GameView()
}
