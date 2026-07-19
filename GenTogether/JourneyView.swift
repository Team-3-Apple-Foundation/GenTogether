//
//  JourneyView.swift
//  GenTogether
//
//  Created by Emily Chen on 16/7/2026.
//  Updated to load challenges + per-user progress from Firestore.
//

import SwiftUI

struct JourneyView: View {
    @StateObject private var viewModel = JourneyViewModel()
    @EnvironmentObject private var authViewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.challenges.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.isEmpty {
                    ContentUnavailableView("No challenges yet", systemImage: "star")
                } else {
                    List(viewModel.challenges) { challenge in
                        let status = viewModel.status(for: challenge)
                        if status == .locked {
                            ChallengeRow(challenge: challenge, status: status, progress: viewModel.progress(for: challenge))
                                .opacity(0.5)
                        } else {
                            NavigationLink {
                                GameView(challenge: challenge)
                            } label: {
                                ChallengeRow(challenge: challenge, status: status, progress: viewModel.progress(for: challenge))
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Journey")
            .task { await viewModel.load(userId: authViewModel.currentUserId) }
            .refreshable { await viewModel.load(userId: authViewModel.currentUserId) }
            .safeAreaInset(edge: .bottom) {
                if viewModel.isUsingFallbackData {
                    Text("Showing sample challenges")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 8)
                }
            }
        }
    }
}

private struct ChallengeRow: View {
    let challenge: Challenge
    let status: ChallengeStatus
    let progress: ChallengeProgress?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundStyle(status == .locked ? Color.secondary : Color.orange)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(challenge.title).font(.headline)
                Text(challenge.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if let progress, progress.stars > 0 {
                    HStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { index in
                            Image(systemName: index < progress.stars ? "star.fill" : "star")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            Spacer()
            Text(statusLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var iconName: String {
        switch status {
        case .locked: return "lock.fill"
        case .unlocked: return "star"
        case .inProgress: return "star.leadinghalf.filled"
        case .completed: return "star.fill"
        }
    }

    private var statusLabel: String {
        switch status {
        case .locked: return "Locked"
        case .unlocked: return "Start"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        }
    }
}

#Preview {
    JourneyView()
        .environmentObject(AuthViewModel())
}
