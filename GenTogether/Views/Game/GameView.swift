//
//  GameView.swift
//  GenTogether
//
//  One play-through of a challenge: loads questions from
//  challenges/{challengeId}/questions, shows each image via Firebase
//  Storage, records every answer, then shows an inline results summary
//  once the session completes.
//

import SwiftUI

struct GameView: View {
    @StateObject private var viewModel: GameViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel

    init(challenge: Challenge) {
        _viewModel = StateObject(wrappedValue: GameViewModel(challenge: challenge))
    }

    var body: some View {
        Group {
            if viewModel.isComplete {
                GameResultsSummaryView(viewModel: viewModel)
            } else if viewModel.isLoading && viewModel.questions.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let question = viewModel.currentQuestion {
                questionView(question)
            } else if let errorMessage = viewModel.errorMessage {
                ContentUnavailableView(errorMessage, systemImage: "exclamationmark.triangle")
            }
        }
        .navigationTitle(viewModel.challenge.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.start(userId: authViewModel.currentUserId) }
    }

    private func questionView(_ question: GameQuestion) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                ProgressView(value: viewModel.progressFraction)
                    .tint(.orange)
                    .padding(.horizontal)

                Text("Question \(viewModel.currentIndex + 1) of \(viewModel.questions.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                StorageImage(path: question.imagePath) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemGroupedBackground))
                        .overlay(ProgressView())
                }
                .frame(maxHeight: 320)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                if let hint = question.hint, !hint.isEmpty {
                    Text(hint)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                HStack(spacing: 16) {
                    Button {
                        Task { await viewModel.submitAnswer(.real, userId: authViewModel.currentUserId) }
                    } label: {
                        Text("Real").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isLoading)

                    Button {
                        Task { await viewModel.submitAnswer(.aiGenerated, userId: authViewModel.currentUserId) }
                    } label: {
                        Text("AI-Generated").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(viewModel.isLoading)
                }
                .padding(.horizontal)
            }
            .padding(.top)
            .padding(.bottom, 32)
        }
    }
}

private struct GameResultsSummaryView: View {
    @ObservedObject var viewModel: GameViewModel

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: passed ? "checkmark.seal.fill" : "arrow.clockwise.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange)

            Text(passed ? "Challenge Complete!" : "Keep Practicing")
                .font(.title.bold())

            if let session = viewModel.session {
                Text("Score: \(session.score)%")
                    .font(.title2)
                Text("\(session.correctAnswers) of \(session.totalQuestions) correct")
                    .foregroundStyle(.secondary)
            }

            if let progress = viewModel.finalProgress {
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        Image(systemName: index < progress.stars ? "star.fill" : "star")
                            .foregroundStyle(.orange)
                    }
                }
            }

            Spacer()
        }
        .padding(.top, 48)
        .padding(.horizontal, 32)
    }

    private var passed: Bool {
        (viewModel.session?.score ?? 0) >= viewModel.challenge.requiredScore
    }
}

#Preview {
    NavigationStack {
        GameView(challenge: LocalSampleData.challenges[0])
            .environmentObject(AuthViewModel())
    }
}
