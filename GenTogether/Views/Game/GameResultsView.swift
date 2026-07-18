//
//  GameResultsView.swift
//  GenTogether
//
//  Reloads and displays a previously saved game session — for revisiting
//  results later (e.g. from a future "past attempts" list) rather than
//  right after finishing, which GameView already shows inline.
//

import SwiftUI

struct GameResultsView: View {
    let userId: String
    let sessionId: String

    @StateObject private var viewModel = GameResultsViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let session = viewModel.session {
                ScrollView {
                    VStack(spacing: 20) {
                        Text("Score: \(session.score)%")
                            .font(.title.bold())
                        Text("\(session.correctAnswers) of \(session.totalQuestions) correct")
                            .foregroundStyle(.secondary)

                        VStack(spacing: 0) {
                            ForEach(Array(viewModel.answers.enumerated()), id: \.element.id) { index, answer in
                                HStack {
                                    Text("Question \(index + 1)")
                                    Spacer()
                                    Image(systemName: answer.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(answer.isCorrect ? .green : .red)
                                }
                                .padding(.vertical, 8)
                                Divider()
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                }
            } else if let errorMessage = viewModel.errorMessage {
                ContentUnavailableView(errorMessage, systemImage: "exclamationmark.triangle")
            }
        }
        .navigationTitle("Results")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load(userId: userId, sessionId: sessionId) }
    }
}
