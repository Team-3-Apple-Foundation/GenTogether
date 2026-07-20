//
//  StorageService.swift
//  GenTogether
//
//  Level media (game questions, tutorial steps, challenge art) now lives in
//  Supabase Storage and Firestore stores its full public URL directly — see
//  GameQuestion/Challenge/TutorialStep.mediaURL — so this Firebase Storage
//  path-resolution service is no longer on that path. Kept only as
//  ready-to-use plumbing for a possible future feature needing Firebase
//  Storage specifically, e.g. user-uploaded profile pictures.
//

import Foundation
import FirebaseStorage

final class StorageService {
    static let shared = StorageService()

    // Computed, not stored: Storage.storage() crashes if FirebaseApp
    // hasn't been configured, so this must only be touched after each
    // method's requireConfigured() guard below has already run.
    private var storage: Storage { Storage.storage() }
    private init() {}

    /// Resolves a Firebase Storage path to a downloadable URL, suitable for
    /// AsyncImage.
    func downloadURL(forStoragePath path: String) async throws -> URL {
        guard !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw StorageServiceError.invalidPath
        }
        try FirebaseEnvironment.requireConfigured()
        let ref = storage.reference(withPath: path)
        do {
            return try await ref.downloadURL()
        } catch {
            throw StorageServiceError.fileUnavailable(path: path, underlying: error)
        }
    }

    /// Uploads image data to a Storage path and returns that same path for
    /// storing in Firestore. Not wired to any current screen — none of the
    /// app's present features (game images, tutorial images) need user
    /// uploads, since those are curated/official content. Provided so a
    /// future feature (e.g. a profile picture) doesn't need another round
    /// of Firebase plumbing. Guarded server-side: storage.rules denies
    /// writes to game-images/, tutorial-images/, and challenge-images/.
    func uploadUserImage(data: Data, path: String, contentType: String = "image/jpeg") async throws -> String {
        try FirebaseEnvironment.requireConfigured()
        let ref = storage.reference(withPath: path)
        let metadata = StorageMetadata()
        metadata.contentType = contentType
        do {
            _ = try await ref.putDataAsync(data, metadata: metadata)
            return path
        } catch {
            throw StorageServiceError.uploadFailed(error)
        }
    }
}

enum StorageServiceError: LocalizedError {
    case invalidPath
    case fileUnavailable(path: String, underlying: Error)
    case uploadFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidPath:
            return "No image path was provided."
        case .fileUnavailable(let path, let underlying):
            return "Couldn't load image \"\(path)\": \(underlying.localizedDescription)"
        case .uploadFailed(let error):
            return "Couldn't upload image: \(error.localizedDescription)"
        }
    }
}
