//
//  TutorialSlide.swift
//  GenTogether
//

import SwiftUI

struct TutorialSlide: View {

    @Environment(\.dismiss) private var dismiss
    var onStartGame: () -> Void = {}

    @State private var step = 0

    private let steps: [Step] = [
        Step(number: 1,
             title: "Analyze",
             description: "Analyze the image or video that is shown to you.",
             mascotAsset: "mascot_analyze"),
        Step(number: 2,
             title: "Identify",
             description: "Tap if you think it is real or AI. You can also swipe.",
             mascotAsset: "mascot_identify"),
        Step(number: 3,
             title: "Learn",
             description: "Get instant feedback and helpful tips to better spot Generative AI.",
             mascotAsset: "mascot_learn")
    ]

    var body: some View {
        VStack(spacing: 0) {
            header

            // Swipeable pager: one page per step, with page dots underneath.
            TabView(selection: $step) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, item in
                    page(for: item, index: index)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            footer
        }
        .background(GTColor.background)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Header

    private var header: some View {
        GTHeader(
            title: "Tutorial",
            leading: AnyView(
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.black)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color(.systemGray5)))
                }
                .accessibilityLabel("Go back")
            )
        )
    }

    // MARK: - Page

    private func page(for item: Step, index: Int) -> some View {
        VStack(spacing: 28) {
            VStack(spacing: 12) {
                Text("\(item.number). \(item.title)")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.black)

                Text(item.description)
                    .font(.system(size: 19))
                    .foregroundStyle(.black.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 32)
            }
            .padding(.top, 32)

            mascot(for: item, index: index)
                .padding(.top, 8)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Mascot

    private func mascot(for item: Step, index: Int) -> some View {
        // Swap in your real assets named in `Step.mascotAsset`. Until they're
        // in Assets.xcassets, this falls back to an SF Symbol so it still builds.
        Group {
            if UIImage(named: item.mascotAsset) != nil {
                Image(item.mascotAsset)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: placeholderSymbol(index))
                    .font(.system(size: 120, weight: .light))
                    .foregroundStyle(GTColor.tip)
            }
        }
        .frame(maxWidth: 240, maxHeight: 240)
    }

    private func placeholderSymbol(_ index: Int) -> String {
        switch index {
        case 0:  return "magnifyingglass"
        case 1:  return "hand.point.up.left"
        default: return "lightbulb"
        }
    }

    // MARK: - Footer

    private var footer: some View {
        Button {
            onStartGame()
        } label: {
            Text("Start game")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, minHeight: 66)
                .background(GTColor.brand)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    // MARK: - Model

    private struct Step {
        let number: Int
        let title: String
        let description: String
        let mascotAsset: String
    }

}

#Preview {
    NavigationStack { TutorialSlide() }
}
