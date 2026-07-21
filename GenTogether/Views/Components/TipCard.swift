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

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay(alignment: .top) {
                switch tip.content {
                case .text(let text):
                    VStack(spacing: 12) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(GTColor.tip)
                            .frame(width: 60, height: 60)
                            .background(Circle().fill(GTColor.tipSoft))
                        Text("Tip of the day!")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(text)
                            .font(.title3)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .minimumScaleFactor(0.5)
                            .lineLimit(5)
                    }
                    .padding(.top, 36)
                    .padding(.horizontal, 20)
                case .image(let name):
                    Image(name)
                        .resizable()
                        .scaledToFill()
                }
            }
            .gtCardBackground()
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
