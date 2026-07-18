//
//  FirebaseSeeder.swift
//  GenTogether
//
//  DEBUG-ONLY. Writes the same sample content as LocalSampleData into
//  Firestore so the game/tutorial/community screens have real backend
//  data to exercise during development, without ever running in a
//  Release build and without duplicating data on every launch (each
//  seed method checks for existing documents first).
//
//  This is intentionally not wired into app startup automatically — call
//  `FirebaseSeeder.seedIfNeeded()` explicitly (e.g. from a hidden debug
//  button, or once from the simulator during development) when you want
//  sample data in your Firebase project.
//

import Foundation
#if DEBUG
import FirebaseFirestore

enum FirebaseSeeder {
    private static let db = Firestore.firestore()

    /// Seeds tutorial steps, one challenge with three questions, and one
    /// community question — but only the pieces that don't already exist.
    static func seedIfNeeded() async {
        guard FirebaseEnvironment.isConfigured else {
            print("FirebaseSeeder: skipping — Firebase isn't configured (GoogleService-Info.plist missing).")
            return
        }
        await seedTutorialSteps()
        await seedChallengeAndQuestions()
        await seedCommunityQuestion()
    }

    private static func seedTutorialSteps() async {
        do {
            let existing = try await db.collection("tutorialSteps").limit(to: 1).getDocuments()
            guard existing.documents.isEmpty else {
                print("FirebaseSeeder: tutorialSteps already has data, skipping.")
                return
            }
            for step in LocalSampleData.tutorialSteps {
                var step = step
                let id = step.id ?? UUID().uuidString
                step.id = nil // let Firestore's Codable support ignore @DocumentID on write
                try db.collection("tutorialSteps").document(id).setData(from: step, merge: true)
            }
            print("FirebaseSeeder: seeded \(LocalSampleData.tutorialSteps.count) tutorial steps.")
        } catch {
            print("FirebaseSeeder: failed to seed tutorialSteps — \(error.localizedDescription)")
        }
    }

    private static func seedChallengeAndQuestions() async {
        do {
            let existing = try await db.collection("challenges").limit(to: 1).getDocuments()
            guard existing.documents.isEmpty else {
                print("FirebaseSeeder: challenges already has data, skipping.")
                return
            }
            guard let challenge = LocalSampleData.challenges.first, let challengeId = challenge.id else { return }
            var challengeToWrite = challenge
            challengeToWrite.id = nil
            try db.collection("challenges").document(challengeId).setData(from: challengeToWrite, merge: true)

            for question in LocalSampleData.questions {
                var question = question
                let id = question.id ?? UUID().uuidString
                question.id = nil
                try db.collection("challenges").document(challengeId)
                    .collection("questions").document(id)
                    .setData(from: question, merge: true)
            }
            print("FirebaseSeeder: seeded 1 challenge with \(LocalSampleData.questions.count) questions.")
        } catch {
            print("FirebaseSeeder: failed to seed challenges — \(error.localizedDescription)")
        }
    }

    private static func seedCommunityQuestion() async {
        do {
            let existing = try await db.collection("communityQuestions").limit(to: 1).getDocuments()
            guard existing.documents.isEmpty else {
                print("FirebaseSeeder: communityQuestions already has data, skipping.")
                return
            }
            var question = LocalSampleData.communityQuestion
            let id = question.id ?? UUID().uuidString
            question.id = nil
            try db.collection("communityQuestions").document(id).setData(from: question, merge: true)
            print("FirebaseSeeder: seeded 1 community question.")
        } catch {
            print("FirebaseSeeder: failed to seed communityQuestions — \(error.localizedDescription)")
        }
    }
}
#endif
