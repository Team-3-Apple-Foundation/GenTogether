//
//  TutorialView.swift
//  GenTogether
//
//  Loads tutorialSteps from Firestore (falling back to bundled sample
//  content via TutorialViewModel when Firestore is empty/unreachable) and
//  presents them as a swipeable page view.
//

import SwiftUI

struct TutorialView: View {
    @StateObject private var viewModel = TutorialViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.steps.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.isEmpty {
                    ContentUnavailableView("No tutorial steps yet", systemImage: "book")
                } else {
                    TabView {
                        ForEach(viewModel.steps) { step in
                            TutorialStepCard(step: step)
                        }
                    }
                    .tabViewStyle(.page)
                    .indexViewStyle(.page(backgroundDisplayMode: .always))
                }
            }
            .navigationTitle("Tutorial")
            .task { await viewModel.loadSteps() }
            .safeAreaInset(edge: .bottom) {
                if viewModel.isUsingFallbackData {
                    Text("Showing sample tutorial content")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 8)
                }
            }
        }
    }
}

private struct TutorialStepCard: View {
    let step: TutorialStep

    var body: some View {
        VStack(spacing: 16) {
            StorageImage(path: step.imagePath) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.orange.opacity(0.15))
                    .overlay(
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)
                    )
            }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 32)

            Text(step.title)
                .font(.title.bold())
            Text(step.description)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
            Spacer()
        }
        .padding(.top, 24)
    }
}

#Preview {
    TutorialView()
}
