//
//  InitialsAvatar.swift
//  GenTogether
//
//  Circular brand-orange avatar showing a name's first letter — used
//  anywhere a person needs a lightweight avatar without a real photo:
//  Community post/comment authors, the Profile hub's account row, and the
//  Guest/Logged-in Account screens.
//

import SwiftUI

struct InitialsAvatar: View {
    let name: String
    var diameter: CGFloat = 44

    var body: some View {
        Circle()
            .fill(GTColor.brand)
            .frame(width: diameter, height: diameter)
            .overlay(
                Text(name.prefix(1).uppercased())
                    .font(letterFont.weight(.bold))
                    .foregroundStyle(.white)
            )
    }

    /// A semantic style (so the letter still responds to the user's Text
    /// Size setting) picked by size tier rather than a raw point size —
    /// a fixed `.system(size:)` wouldn't scale with accessibility text
    /// sizes at all, and one single semantic style would look right at
    /// the small 36–44pt row usage but tiny inside a large hero avatar.
    private var letterFont: Font {
        switch diameter {
        case ..<40: .caption
        case ..<60: .subheadline
        default: .title
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        InitialsAvatar(name: "Guest")
        InitialsAvatar(name: "Ava", diameter: 72)
    }
    .padding()
    .background(GTColor.background)
}
