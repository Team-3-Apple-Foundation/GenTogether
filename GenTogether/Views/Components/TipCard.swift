//
//  TipCard.swift
//  GenTogether
//
//  A square card on the Home screen that shows a single tip. The tip's
//  content is either text or an image (see Tip / TipContent).
//

import SwiftUI

struct TipCard: View {
    let tip: Tip
    /// Only the first tip on Home shows the "Tip of the Day" heading.
    var showsHeader: Bool = false

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay(alignment: .top) {
                VStack(spacing: 12) {
                    if showsHeader {
                        Text("Tip of the Day")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.primary)
                            // This card is a fixed 1:1 square that clips
                            // its contents — same shrink-to-fit guard as
                            // the tip text below, so a large accessibility
                            // text size doesn't get clipped by the card.
                            .minimumScaleFactor(0.5)
                            .lineLimit(2)
                    }

                    content
                }
                .padding(.top, 28)
                .padding(.horizontal, 20)
            }
            .gtCardBackground()
    }

    /// The part below the "Tip of the day!" header — differs per tip kind.
    @ViewBuilder
    private var content: some View {
        switch tip.content {
        case .text(let text):
            Text(text)
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .minimumScaleFactor(0.5)
                .lineLimit(5)
        case .image(let name):
            Image(name)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 200)
        case .imageWithText(let name, let caption):
            Image(name)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 180)
            Text(caption)
                .font(.title3)
                .multilineTextAlignment(.center)
//                .foregroundStyle(.secondary)
                .foregroundStyle(.black)
                .minimumScaleFactor(0.5)
                .lineLimit(5)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        TipCard(tip: Tip(content: .text("AI-generated images often struggle with hands, text, and repeating background patterns — look closely before you decide.")))
        TipCard(tip: Tip(content: .image("food4")))
    }
    .padding()
    .background(GTColor.background)
}
