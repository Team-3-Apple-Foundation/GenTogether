//
//  Challenge.swift
//  GenTogether
//
//  Firestore path: challenges/{challengeId}
//  Document IDs are Firestore auto-generated — never assume a fixed id;
//  always read `Challenge.id` off the fetched document.
//  `rounds[].mediaUrl` is a full public URL into the Supabase Storage
//  `level-media` bucket — read it directly, no path resolution needed.
//

import Foundation
import FirebaseFirestore

struct Challenge: Codable, Identifiable, Sendable {
    @DocumentID var id: String?
    var category: ChallengeCategory
    var rounds: [ChallengeRound]
}

struct ChallengeRound: Codable, Identifiable, Sendable {
    var id: String
    var isImage: Bool
    var mediaUrl: String
    var isAI: Bool
}

enum ChallengeCategory: String, CaseIterable, Codable, Sendable {
    case animals
    case artAndCraft = "art_and_craft"
    case nature
    case foods

    var displayName: String {
        switch self {
        case .animals: "Animals"
        case .artAndCraft: "Art and Craft"
        case .nature: "Nature"
        case .foods: "Foods"
        }
    }
}
