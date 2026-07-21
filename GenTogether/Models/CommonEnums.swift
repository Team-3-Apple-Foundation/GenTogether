//
//  CommonEnums.swift
//  GenTogether
//
//  Controlled-vocabulary values shared across Firestore models. Raw String
//  enums keep Firestore documents human-readable while giving the app
//  compile-time safety instead of untyped strings.
//

import Foundation

/// Distinguishes anonymous (guest) sign-ins from permanent registered accounts.
/// Both share the same `users` collection; this field is the discriminator.
enum AccountType: String, Codable, Sendable {
    case guest
    case registered
}
