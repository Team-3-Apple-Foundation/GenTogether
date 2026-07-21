
import SwiftUI

struct JourneyView: View {
    private let challenges = GameChallenge.samples
    
    @Environment(GameProgress.self) private var progress
    
    var body:some View{
        NavigationStack{
            ScrollView{
                VStack(spacing: 16){
                    Text("Select a challenge below to play.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 4)
                    
                    ForEach(challenges) {challenge in
                        let status = progress.status(forChallengeNumber: challenge.number)
                        
                        NavigationLink{
                            GameView(challenge: challenge)
                        } label: {
                            ChallengeRow (challenge: challenge, status: status)
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
            .navigationTitle("Journey")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar{
                ToolbarItem(placement: .topBarTrailing){
                    Button("Reset", systemImage: "arrow.counterclockwise"){
                        progress.resetAllProgress()
                    }
                }
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

struct GameChallenge: Identifiable {
    let id = UUID()
    let number: Int
    let title: String
//    let status: ChallengeStatus
    
    let rounds: [GameRound]
    
    static let samples: [GameChallenge] = [
        GameChallenge(number: 1, title: "Nature",   rounds: GameRound.nature),
        GameChallenge(number: 2, title: "Animals",  rounds: GameRound.animals),
        GameChallenge(number: 3, title: "Art",      rounds: GameRound.art),
        GameChallenge(number: 4, title: "Food",     rounds: GameRound.food),
//        GameChallenge(number: 5, title: "Faces",  rounds: GameRound.samples),
//        GameChallenge(number: 6, title: "Places", rounds: GameRound.samples),
//        GameChallenge(number: 7, title: "Buildings", rounds: GameRound.samples),
//        GameChallenge(number: 8, title: "Cars",   rounds: GameRound.samples),
//        GameChallenge(number: 9, title: "Flowers", rounds: GameRound.samples),
        GameChallenge(number: 10, title: "Art",     rounds: GameRound.art)
    ]
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
