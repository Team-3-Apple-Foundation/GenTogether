//
//  FirestoreTransaction.swift
//  GenTogether
//
//  Thin async/await wrapper around Firestore's completion-based
//  runTransaction API, so services can `try await` a transaction body
//  instead of juggling NSErrorPointer/completion callbacks by hand.
//

import Foundation
import FirebaseFirestore

extension Firestore {
    /// Runs `block` inside a Firestore transaction and returns its result.
    /// `block` must only perform synchronous transaction reads/writes
    /// (per Firestore's transaction rules) and may throw to abort.
    func runTransaction<T>(_ block: @escaping (Transaction) throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            self.runTransaction({ transaction, errorPointer -> Any? in
                do {
                    return try block(transaction)
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            }, completion: { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let value = result as? T {
                    continuation.resume(returning: value)
                } else {
                    continuation.resume(throwing: FirestoreTransactionError.unexpectedResultType)
                }
            })
        }
    }
}

enum FirestoreTransactionError: LocalizedError {
    case unexpectedResultType

    var errorDescription: String? {
        "The database transaction returned an unexpected result."
    }
}
