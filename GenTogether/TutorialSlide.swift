//
//  TutorialSlide.swift
//  GenTogether
//

import SwiftUI

struct TutorialSlide: View {

    @Environment(\.dismiss) private var dismiss
    var onStartGame: () -> Void = {}

    @State private var step = 0
    @State private var mascotVisible = false

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

    private var current: Step { steps[step] }
    private var isLast: Bool { step == steps.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 28) {
                    // Step text at top
                    VStack(spacing: 12) {
                        Text("\(current.number). \(current.title)")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.black)

                        Text(current.description)
                            .font(.system(size: 19))
                            .foregroundStyle(.black.opacity(0.75))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 32)
                    }
                    .padding(.top, 32)
                    // Slide the text block down-in on each step change
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .id("text-\(step)")   // forces a fresh transition per step

                    // Mascot below, animating in
                    mascot
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 24)
            }

            footer
        }
        .background(Palette.screen)
        .navigationBarBackButtonHidden(true)
        .onAppear { animateMascotIn() }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("Tutorial")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.black)

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(.black)
                        .clipShape(Circle())
                }
                .accessibilityLabel("Go back")
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .background(Palette.tan)
    }

    // MARK: - Mascot

    private var mascot: some View {
        // Swap Image(current.mascotAsset) for your real assets. Until they're
        // in Assets.xcassets, this falls back to an SF Symbol so it still
        // builds and animates.
        Group {
            if UIImage(named: current.mascotAsset) != nil {
                Image(current.mascotAsset)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: placeholderSymbol)
                    .font(.system(size: 120, weight: .light))
                    .foregroundStyle(Palette.iconYellow)
            }
        }
        .frame(maxWidth: 240, maxHeight: 240)
        .scaleEffect(mascotVisible ? 1 : 0.6)
        .opacity(mascotVisible ? 1 : 0)
        .id("mascot-\(step)")
    }

    private var placeholderSymbol: String {
        switch step {
        case 0:  return "magnifyingglass"
        case 1:  return "hand.point.up.left"
        default: return "lightbulb"
        }
    }

    // MARK: - Footer

    private var footer: some View {
        Button(action: advance) {
            Text(isLast ? "Start game" : "Continue")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, minHeight: 66)
                .background(Palette.tan)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    // MARK: - Logic

    private func advance() {
        if isLast {
            onStartGame()
            return
        }
        mascotVisible = false
        withAnimation(.easeInOut(duration: 0.3)) {
            step += 1
        }
        animateMascotIn()
    }

    private func animateMascotIn() {
        mascotVisible = false
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.15)) {
            mascotVisible = true
        }
    }

    // MARK: - Model

    private struct Step {
        let number: Int
        let title: String
        let description: String
        let mascotAsset: String
    }

    // MARK: - Colors

    private enum Palette {
        static let tan        = Color(red: 0.84, green: 0.72, blue: 0.57)
        static let screen     = Color(red: 0.96, green: 0.96, blue: 0.96)
        static let iconYellow = Color(red: 0.98, green: 0.80, blue: 0.42)
    }
}

#Preview {
    NavigationStack { TutorialSlide() }
}
