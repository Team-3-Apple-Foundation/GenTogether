//
//  JourneyView.swift
//  GenTogether
//
//  Created by Emily Chen on 16/7/2026.
//  Updated to load challenges from Firestore (challenges/rounds schema).
//

import SwiftUI

struct JourneyView: View {
    @StateObject private var viewModel = JourneyViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.challenges.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = viewModel.errorMessage, viewModel.challenges.isEmpty {
                    ContentUnavailableView(errorMessage, systemImage: "exclamationmark.triangle")
                } else if viewModel.isEmpty {
                    ContentUnavailableView("No challenges yet", systemImage: "star")
                } else {
                    List(viewModel.challenges, id: \.journeyListId) { challenge in
                        NavigationLink {
                            GameView(challengeId: challenge.id ?? "")
                        } label: {
                            ChallengeRow(challenge: challenge)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Journey")
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
        }
    }
}

private extension Challenge {
    var journeyListId: String {
        id ?? "\(category.rawValue)-\(rounds.count)"
    }
}

private struct ChallengeRow: View {
    let challenge: Challenge

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "star")
                .font(.title2)
                .foregroundStyle(Color.orange)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(challenge.category.displayName).font(.headline)
                Text("\(challenge.rounds.count) rounds")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    JourneyView()
}
