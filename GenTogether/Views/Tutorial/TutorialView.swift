//
//  tut.swift
//  GenTogether
//
//  Created by Muthu Kumaran on 20/7/2026.
//

import Foundation
//
//  TutorialView.swift
//  GenTogether
//

import SwiftUI

struct TutorialView: View {

    // MARK: - Dependencies

    @Environment(\.dismiss) private var dismiss
    var onStartGame: () -> Void = {}

    // MARK: - State

    @State private var highlightedIndex: Int = 1

    // MARK: - Data

    private let steps: [Step] = [
        Step(number: 1,
             title: "Analyze",
             description: "Analyze the image or video that is shown to you.",
             icon: "magnifyingglass"),
        Step(number: 2,
             title: "Identify",
             description: "Tap if you think it is real or AI. You can also swipe.",
             icon: "hand.point.up.left"),
        Step(number: 3,
             title: "Learn",
             description: "Get instant feedback and helpful tips to better spot Generative AI.",
             icon: "lightbulb")
    ]

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 16) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        card(for: step, highlighted: index == highlightedIndex)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }

            Button(action: onStartGame) {
                Text("Start game")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 66)
                    .background(Palette.tan)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .background(Palette.screen)
        .navigationBarBackButtonHidden(true)
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

    // MARK: - Card

    private func card(for step: Step, highlighted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                Image(systemName: step.icon)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(.black)
                    .frame(width: 62, height: 62)
                    .background(Palette.iconYellow)
                    .clipShape(Circle())

                Text("\(step.number). \(step.title)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.black)
            }

            Text(step.description)
                .font(.system(size: 20))
                .foregroundStyle(.black)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Local types

    private struct Step: Identifiable {
        let id = UUID()
        let number: Int
        let title: String
        let description: String
        let icon: String
    }

    private enum Palette {
        static let tan        = Color(red: 0.84, green: 0.72, blue: 0.57)
        static let iconYellow = Color(red: 0.98, green: 0.80, blue: 0.42)
        static let screen     = Color(red: 0.96, green: 0.96, blue: 0.96)
        
    }
}

#Preview {
    NavigationStack { TutorialSlide() }
}
