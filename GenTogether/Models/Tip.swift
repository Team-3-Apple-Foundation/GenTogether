//
//  Tip.swift
//  GenTogether
//
//  A single tip shown on the Home screen. A tip is either a piece of
//  text or an image (referenced by its name in the asset catalog).
//

import Foundation

enum TipContent {
    case text(String)
    case image(String)
}

struct Tip: Identifiable {
    let id = UUID()
    let content: TipContent
}

extension Tip {
    /// Hardcoded sample tips shown on Home for now. Later these will come
    /// from Firebase instead of being listed here.
    static let samples: [Tip] = [
        Tip(content: .text("AI-generated images often struggle with hands, text, and repeating background patterns — look closely before you decide.")),
        Tip(content: .text("Check reflections and shadows — AI often gets lighting subtly wrong.")),
        Tip(content: .image("food4")),
        Tip(content: .text("Zoom in on fine details like jewellery, teeth, and strands of hair.")),
    ]
}
