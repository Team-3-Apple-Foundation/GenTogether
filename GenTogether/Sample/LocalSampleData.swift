//
//  LocalSampleData.swift
//  GenTogether
//
//  DEVELOPMENT / SAMPLE CONTENT — not read from Firestore.
//
//  Bundled fallback so the Tutorial screen still renders something
//  reasonable when Firestore has no active content yet (e.g. a fresh
//  Firebase project before FirebaseSeeder / the CLI import has run) or is
//  briefly unreachable. Per the integration spec, this fallback is used
//  ONLY for tutorial steps — never for authentication, challenges, user
//  progress, or community writes, all of which always go straight to
//  Firestore. Challenges in particular have no local fallback: they're
//  seeded manually (see the migrate-level-media script and Firestore
//  console), not via LocalSampleData/FirebaseSeeder.
//

import Foundation

enum LocalSampleData {
    static let tutorialSteps: [TutorialStep] = [
        TutorialStep(
            id: "sample-analyse",
            title: "Analyse",
            description: "Look closely at the image. Check the lighting, textures, and small details before deciding.",
            mediaURL: nil,
            stepOrder: 1,
            isActive: true
        ),
        TutorialStep(
            id: "sample-swipe",
            title: "Swipe",
            description: "Swipe or tap to choose whether you think the image is Real or AI-generated.",
            mediaURL: nil,
            stepOrder: 2,
            isActive: true
        ),
        TutorialStep(
            id: "sample-learn",
            title: "Learn",
            description: "See the explanation after each round to sharpen your eye for next time.",
            mediaURL: nil,
            stepOrder: 3,
            isActive: true
        )
    ]

    static let communityQuestion = CommunityQuestion(
        id: "sample-community-question",
        question: "What's one clue that helped you spot an AI-generated image this week?",
        displayDate: Date(),
        isActive: true
    )
}
