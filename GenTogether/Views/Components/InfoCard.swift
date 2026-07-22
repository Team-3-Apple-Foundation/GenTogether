//
//  InfoCard.swift
//  GenTogether
//
//  White, rounded, drop-shadowed card with a colored icon circle on the
//  left/top and a title + body of text. Used for the "last game" and
//  "tip of the day" cards on the home screen.
//

import SwiftUI

/// The app's shared white/rounded/drop-shadowed card background — the same
/// look InfoCard uses on Home, factored out so other cards (e.g. the
/// Interests toggle list) can match it without re-declaring the styling.
extension View {
    func gtCardBackground(cornerRadius: CGFloat = 18) -> some View {
        self
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
    }
}

struct InfoCard: View {
    let iconName: String
    let iconColor: Color
    let iconBackground: Color
    let title: String
    let body_: String

    init(
        iconName: String,
        iconColor: Color,
        iconBackground: Color,
        title: String,
        body: String
    ) {
        self.iconName = iconName
        self.iconColor = iconColor
        self.iconBackground = iconBackground
        self.title = title
        self.body_ = body
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Circle()
                .fill(iconBackground)
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(iconColor)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(body_)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .gtCardBackground()
    }
}

#Preview {
    VStack(spacing: 16) {
        InfoCard(
            iconName: "checkmark",
            iconColor: GTColor.success,
            iconBackground: GTColor.successSoft,
            title: "7 out of 10 Correct",
            body: "Last game played."
        )
        InfoCard(
            iconName: "lightbulb.fill",
            iconColor: GTColor.tip,
            iconBackground: GTColor.tipSoft,
            title: "Tip of the Day",
            body: "AI-generated images often struggle with hands, text, and repeating background patterns — look closely before you decide."
        )
    }
    .padding()
    .background(GTColor.background)
}
