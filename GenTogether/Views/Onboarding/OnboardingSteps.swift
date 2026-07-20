//
//  OnboardingSteps.swift
//  GenTogether
//

import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case name, familiarity, goal, interests, dailyTime, fontSize

    var question: String {
        switch self {
        case .name:        return "What should we call you?"
        case .familiarity: return "Are you familiar with Generative AI?"
        case .goal:        return "What brings you here today?"
        case .interests:   return "What are you interested in?"
        case .dailyTime:   return "How much time would you like to learn each day?"
        case .fontSize:    return "What size is comfortable for you to read the text?"
        }
    }

    var isLast: Bool { self == OnboardingStep.allCases.last }
}

struct OnboardingView: View {

    @ObservedObject var onboardingViewModel: OnboardingViewModel

    @State private var step: OnboardingStep = .name

    private let fontOptions: [TextSizePreference] = [.standard, .large]

    var body: some View {
        VStack(spacing: 0) {
            header
            progressBar
            

            ScrollView {
                VStack(spacing: 28) {
                    
                    Text(step.question)
                        .font(.system(size: 22, weight: .medium))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 32)
                        .padding(.top, 28)

                    content
                }
                .padding(.bottom, 24)
            }

            footer
        }
        .background(Palette.screen)
        .animation(.easeInOut(duration: 0.25), value: step)
        .alert("Something went wrong",
               isPresented: .constant(onboardingViewModel.errorMessage != nil)) {
            Button("OK") { onboardingViewModel.errorMessage = nil }
        } message: {
            Text(onboardingViewModel.errorMessage ?? "")
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("Onboarding")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.black)

            HStack {
                if step != .name {
                    Button(action: goBack) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.black)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Go back")
                }
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Palette.tan)
    }

    // MARK: - Progress

    private var progressBar: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingStep.allCases, id: \.self) { s in
                Capsule()
                    .fill(s.rawValue <= step.rawValue ? Palette.tan : Palette.inactive)
                    .frame(height: 6)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .accessibilityElement()
        .accessibilityLabel("Step \(step.rawValue + 1) of \(OnboardingStep.allCases.count)")
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch step {
        case .name:
            HStack(spacing: 10) {
                TextField("Choose a username", text: $onboardingViewModel.name)
                    .font(.system(size: 16))
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()

                Image(systemName: "person.crop.circle")
                    .foregroundStyle(.black.opacity(0.35))
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.black.opacity(0.15), lineWidth: 1)
            )
            .padding(.horizontal, 40)

        case .familiarity:
            optionList(OnboardingViewModel.familiarityOptions) {
                onboardingViewModel.aiFamiliarity == $0
            } action: {
                onboardingViewModel.aiFamiliarity = $0
            }

        case .goal:
            optionList(OnboardingViewModel.goalOptions) {
                onboardingViewModel.learningGoal == $0
            } action: {
                onboardingViewModel.learningGoal = $0
            }

        case .interests:
            optionList(OnboardingViewModel.interestOptions) {
                onboardingViewModel.interests.contains($0)
            } action: {
                toggleInterest($0)
            }

        case .dailyTime:
            VStack(spacing: 12) {
                ForEach(OnboardingViewModel.minuteOptions, id: \.self) { minutes in
                    optionPill("\(minutes) minutes",
                               selected: onboardingViewModel.learningMinutes == minutes) {
                        onboardingViewModel.learningMinutes = minutes
                    }
                }
            }
            .padding(.horizontal, 40)

        case .fontSize:
            VStack(spacing: 20) {
                ForEach(fontOptions, id: \.self) { size in
                    fontCard(size)
                }
            }
        }
    }

    private func optionList(_ options: [String],
                            selected: @escaping (String) -> Bool,
                            action: @escaping (String) -> Void) -> some View {
        VStack(spacing: 12) {
            ForEach(options, id: \.self) { option in
                optionPill(option, selected: selected(option)) {
                    action(option)
                }
            }
        }
        .padding(.horizontal, 40)
    }

    private func optionPill(_ title: String,
                            selected: Bool,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(selected ? Palette.tan : Palette.pill)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(selected ? .black.opacity(0.4) : .clear, lineWidth: 2)
                )
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func fontCard(_ size: TextSizePreference) -> some View {
        let selected = onboardingViewModel.textSize == size
        let scale = fontScale(for: size)

        return Button {
            onboardingViewModel.textSize = size
        } label: {
            VStack(spacing: 4) {
                Text("Aa")
                    .font(.system(size: 20 * scale, weight: .medium))
                Text(label(for: size))
                    .font(.system(size: 12 * scale))
            }
            .foregroundStyle(.black)
            .frame(width: 72 * scale, height: 60 * scale)
            .background(selected ? Palette.selectedBlue : .white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selected ? Palette.blue : .black.opacity(0.12),
                            lineWidth: selected ? 2 : 1)
            )
            .overlay(alignment: .topTrailing) {
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Palette.blue)
                        .background(Circle().fill(.white))
                        .offset(x: 5, y: -5)
                }
            }
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 10) {
            Button(action: advance) {
                Group {
                    if onboardingViewModel.isLoading {
                        ProgressView()
                    } else {
                        Text(step.isLast ? "Complete" : "Continue")
                    }
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(canContinue ? Palette.tan : Palette.tan.opacity(0.45))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(!canContinue || onboardingViewModel.isLoading)
            .padding(.horizontal, 40)

            if step == .name {
                Button("Skip for now") {
                    onboardingViewModel.name = ""
                    step = .familiarity
                }
                .font(.system(size: 14))
                .foregroundStyle(.black.opacity(0.6))
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
        }
        .padding(.bottom, 20)
    }

    // MARK: - Logic

    private var canContinue: Bool {
        switch step {
        case .name:
            return !onboardingViewModel.name.trimmingCharacters(in: .whitespaces).isEmpty
        case .familiarity:
            return !onboardingViewModel.aiFamiliarity.isEmpty
        case .goal:
            return !onboardingViewModel.learningGoal.isEmpty
        case .interests:
            return !onboardingViewModel.interests.isEmpty
        case .dailyTime, .fontSize:
            return true
        }
    }

    private func toggleInterest(_ option: String) {
        if onboardingViewModel.interests.contains(option) {
            onboardingViewModel.interests.remove(option)
        } else {
            onboardingViewModel.interests.insert(option)
        }
    }

    private func advance() {
        guard canContinue else { return }
        if let next = OnboardingStep(rawValue: step.rawValue + 1) {
            step = next
        } else {
            Task { await onboardingViewModel.completeOnboarding() }
        }
    }

    private func goBack() {
        if let prev = OnboardingStep(rawValue: step.rawValue - 1) {
            step = prev
        }
    }

    private func fontScale(for size: TextSizePreference) -> CGFloat {
        switch size {
        case .standard:   return 1.0
        case .large:      return 1.4
        case .extraLarge: return 1.7
        }
    }

    private func label(for size: TextSizePreference) -> String {
        switch size {
        case .standard:   return "Normal"
        case .large:      return "Larger"
        case .extraLarge: return "Largest"
        }
    }

    // MARK: - Colors

    private enum Palette {
        static let tan          = Color(red: 0.84, green: 0.72, blue: 0.57)
        static let screen       = Color(red: 0.96, green: 0.96, blue: 0.96)
        static let pill         = Color(red: 0.90, green: 0.90, blue: 0.91)
        static let inactive     = Color(red: 0.87, green: 0.87, blue: 0.88)
        static let blue         = Color(red: 0.10, green: 0.45, blue: 0.91)
        static let selectedBlue = Color(red: 0.80, green: 0.88, blue: 0.98)
    }
}

#Preview {
    OnboardingView(
        onboardingViewModel: OnboardingViewModel(
            userIdProvider: { "preview-user" }
        )
    )
}
