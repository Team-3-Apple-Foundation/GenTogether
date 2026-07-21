//
//  Color+Hex.swift
//  GenTogether
//

import SwiftUI

extension Color {
    /// Creates a color from a 6-digit hex string (e.g. "D8AE86"), with or
    /// without a leading "#".
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)

        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

/// GenTogether brand palette. Approximate values picked off the home
/// screen design reference — swap for exact hex values if the design
/// system formalizes them later.
enum GTColor {
    /// Header background and primary CTA button — warm orange/brown.
    static let brand = Color(.orange)
    /// Screen background — warm off-white.
    static let background = Color(hex: "F5F4F1")
    /// "Last game" card icon circle — soft green.
    static let successSoft = Color(hex: "DCEEDB")
    static let success = Color(hex: "4CAF50")
    /// "Tip of the Day" card icon circle — warm gold.
    static let tipSoft = Color(hex: "F6E2B3")
    static let tip = Color(hex: "C9962C")
}
