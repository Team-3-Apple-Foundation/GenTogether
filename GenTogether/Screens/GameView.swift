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
                VStack(spacing: 16) {
                    Text("You got \(score) out of \(rounds.count)")
                        .font(.title.weight(.bold))

                    ForEach(results) { result in
                        HStack(spacing: 12) {
                            Image(systemName: result.isCorrect ? "checkmark.circle.fill" : "xmark.circle")
                                .foregroundStyle(result.isCorrect ? .green : .orange)
                            Text(result.isCorrect ? "Correct" : "Not quite")
                            Spacer()
                        }
                        .font(.title3)
                    }
                }
            }
        }
        .padding(20)
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
        results.append(RoundResult(round: currentRound, answer: answer))
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
    let round: GameRound
    let answer: Answer

    var isCorrect: Bool {
        (answer == .ai) == round.isAI
    }
}



#Preview {
    GameView()
}
