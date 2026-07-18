//
//  LocalSampleData.swift
//  GenTogether
//
//  DEVELOPMENT / SAMPLE CONTENT — not read from Firestore.
//
//  Bundled fallback so the Tutorial and Journey screens still render
//  something reasonable when Firestore has no active content yet (e.g. a
//  fresh Firebase project before FirebaseSeeder / the CLI import has run)
//  or is briefly unreachable. Per the integration spec, this fallback is
//  used ONLY for tutorial steps and challenges — never for authentication,
//  user progress, game answers, or community writes, all of which always
//  go straight to Firestore.
//

import Foundation

enum LocalSampleData {
    static let tutorialSteps: [TutorialStep] = [
        TutorialStep(
            id: "sample-analyse",
            title: "Analyse",
            description: "Look closely at the image. Check the lighting, textures, and small details before deciding.",
            imagePath: nil,
            stepOrder: 1,
            isActive: true
        ),
        TutorialStep(
            id: "sample-swipe",
            title: "Swipe",
            description: "Swipe or tap to choose whether you think the image is Real or AI-generated.",
            imagePath: nil,
            stepOrder: 2,
            isActive: true
        ),
        TutorialStep(
            id: "sample-learn",
            title: "Learn",
            description: "See the explanation after each round to sharpen your eye for next time.",
            imagePath: nil,
            stepOrder: 3,
            isActive: true
        )
    ]

    static let challenges: [Challenge] = [
        Challenge(
            id: "sample-spot-the-difference",
            title: "Spot the Difference",
            description: "Warm up by telling real photos apart from AI-generated ones.",
            difficulty: "beginner",
            challengeOrder: 1,
            requiredScore: 70,
            imagePath: nil,
            isActive: true
        )
    ]

    static let questions: [GameQuestion] = [
        GameQuestion(
            id: "sample-question-1",
            imagePath: "game-images/flower-001.jpg",
            imageType: .real,
            correctAnswer: .real,
            hint: "Look at the petal edges.",
            explanation: "Real photo — note the natural imperfections in the petals.",
            questionOrder: 1,
            isActive: true
        ),
        GameQuestion(
            id: "sample-question-2",
            imagePath: "game-images/portrait-002.jpg",
            imageType: .aiGenerated,
            correctAnswer: .aiGenerated,
            hint: "Check the hands and background details.",
            explanation: "AI-generated — the background pattern repeats unnaturally.",
            questionOrder: 2,
            isActive: true
        ),
        GameQuestion(
            id: "sample-question-3",
            imagePath: "game-images/landscape-003.jpg",
            imageType: .real,
            correctAnswer: .real,
            hint: "Look for consistent shadows.",
            explanation: "Real photo — the shadows are consistent with a single light source.",
            questionOrder: 3,
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
