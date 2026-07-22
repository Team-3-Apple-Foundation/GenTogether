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
    case imageWithText(name: String, caption: String)
}

struct Tip: Identifiable {
    let id = UUID()
    let content: TipContent
}

extension Tip {
    /// Hardcoded sample tips shown on Home for now. Later these will come
    /// from Firebase instead of being listed here.
    static let samples: [Tip] = [
        Tip(content: .imageWithText(name: "sm_icon", caption: "AI often struggles to draw the right  number of fingers on a hand. Count them to check.")),
        Tip(content: .imageWithText(name: "real_hand", caption: "A real photo. Notice the natural, correctly-shaped fingers.")),
        Tip(content: .imageWithText(name: "AI_hand",  caption: "AI-made. Look for extra or bent fingers or smooth texture.")),
        Tip(content: .imageWithText(name: "AI_logo",  caption: "AI-generated images often has this logo.")),
//        Tip(content: .text("AI-generated images often struggle with hands, text, and repeating background patterns — look closely before you decide.")),
//        Tip(content: .text("Check reflections and shadows — AI often gets lighting subtly wrong.")),
//        Tip(content: .text("Zoom in on fine details like jewellery, teeth, and strands of hair.")),
    ]
}
