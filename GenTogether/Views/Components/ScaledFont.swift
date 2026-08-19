//
//  ScaledFont.swift
//  GenTogether
//
//  A handful of screens (Tutorial, Onboarding) set fonts with a raw point
//  size instead of a semantic style like .title or .body, so they don't
//  respond to Dynamic Type at all — there's no size *category* being
//  read there, just a fixed number, so no environment value can fix it.
//  This scales those call sites directly off the user's saved Text Size
//  preference (@AppStorage), independent of environment propagation.
//

import SwiftUI

extension View {
    func scaledFont(size: CGFloat, weight: Font.Weight = .regular) -> some View {
        modifier(ScaledFont(size: size, weight: weight))
    }
}

private struct ScaledFont: ViewModifier {
    @AppStorage("textSizeOption") private var textSizeOption: TextSizeOption = .medium
    let size: CGFloat
    let weight: Font.Weight

    func body(content: Content) -> some View {
        content.font(.system(size: size * textSizeOption.scale, weight: weight))
    }
}
