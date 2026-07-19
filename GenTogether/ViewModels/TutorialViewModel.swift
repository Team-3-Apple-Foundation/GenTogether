//
//  TutorialViewModel.swift
//  GenTogether
//
//  Loads tutorialSteps from Firestore, falling back to bundled sample
//  content (LocalSampleData) when Firestore has no active steps yet or is
//  temporarily unreachable, so the tutorial screen is never empty.
//

import Foundation
import Combine

@MainActor
final class TutorialViewModel: ObservableObject {
    @Published private(set) var steps: [TutorialStep] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var isUsingFallbackData = false

    private let tutorialService: TutorialService

    init(tutorialService: TutorialService? = nil) {
        self.tutorialService = tutorialService ?? .shared
    }

    var isEmpty: Bool { !isLoading && steps.isEmpty }

    func loadSteps() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let remoteSteps = try await tutorialService.fetchActiveTutorialSteps()
            if remoteSteps.isEmpty {
                steps = LocalSampleData.tutorialSteps
                isUsingFallbackData = true
            } else {
                steps = remoteSteps
                isUsingFallbackData = false
            }
        } catch {
            errorMessage = error.localizedDescription
            steps = LocalSampleData.tutorialSteps
            isUsingFallbackData = true
        }
    }
}
