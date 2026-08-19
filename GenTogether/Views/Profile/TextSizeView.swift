//
//  TextSizeView.swift
//  GenTogether
//
//  Pushed from ProfileView's "Text Size" row. Lets the user pick and save
//  a preferred reading size. This is a device-level display preference —
//  saved with @AppStorage (UserDefaults), not Firestore, so it doesn't
//  need to be signed in or synced across devices.
//
//  Scope note: this screen only lets the user pick and save a size. It
//  does NOT yet make the rest of the app (Home, Journey, ...) actually
//  render text at that size — that's a separate, larger change for later.
//

import SwiftUI

/// The three reading sizes the user can choose between, each mapped to an
/// actual point size for the live preview.
enum TextSizeOption: String, CaseIterable, Identifiable {
    case small, medium, large

    var id: String { rawValue }

    var label: String {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        }
    }

    var pointSize: CGFloat {
        switch self {
        case .small: 14
        case .medium: 17
        case .large: 21
        }
    }

    /// Maps this preference onto SwiftUI's built-in Dynamic Type scale.
    /// Applied app-wide in AppRootView via `.environment(\.dynamicTypeSize:)`
    /// — every view using a semantic font style (.body, .title, ...)
    /// automatically resizes to match; fixed-point font sizes don't.
    var dynamicTypeSize: DynamicTypeSize {
        switch self {
        case .small: .medium
        case .medium: .large
        case .large: .accessibility1
        }
    }

    /// Multiplier used by `.scaledFont(size:weight:)` for the handful of
    /// call sites still hardcoded to a raw point size rather than a
    /// semantic style — see ScaledFont.swift.
    var scale: CGFloat {
        switch self {
        case .small: 0.85
        case .medium: 1.0
        case .large: 1.2
        }
    }
}

struct TextSizeView: View {
    // The saved preference. TextSizeOption's String raw value lets
    // @AppStorage store/read it directly, no extra encoding needed.
    @AppStorage("textSizeOption") private var savedOption: TextSizeOption = .medium

    // The size tapped but not yet saved — nil means "no change yet, just
    // show whatever's already saved". Keeping this separate from
    // `savedOption` is what lets the preview update instantly on tap
    // while Save Changes is what actually commits it.
    @State private var pendingOption: TextSizeOption?

    @Environment(\.dismiss) private var dismiss

    private var currentOption: TextSizeOption { pendingOption ?? savedOption }

    var body: some View {
        VStack(spacing: 0) {
            GTHeader(title: "Profile", leading: AnyView(backButton))

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    titleBlock
                    previewCard
                    optionsList
                }
                .padding(20)
            }
            .background(GTColor.background)

            saveButton
        }
        .background(GTColor.background)
        // GTHeader is this screen's whole header — the system nav bar
        // (and its own back button) stays hidden so there's only one.
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: Sections

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Text Size")
                .font(.title.bold())
            Text("Select a size comfortable to read.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preview")
                .font(.subheadline.weight(.bold))
            Text("This is how the text will appear on this app.")
                .font(.system(size: currentOption.pointSize))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(GTColor.tipSoft)
        )
    }

    private var optionsList: some View {
        VStack(spacing: 12) {
            ForEach(TextSizeOption.allCases) { option in
                optionRow(option)
            }
        }
    }

    private func optionRow(_ option: TextSizeOption) -> some View {
        let isSelected = option == currentOption

        return Button {
            pendingOption = option
        } label: {
            HStack {
                Text(option.label)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.black)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? GTColor.brand : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? .clear : Color(.systemGray4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var saveButton: some View {
        Button {
            savedOption = currentOption
            dismiss()
        } label: {
            Text("Save Changes")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 50)
        }
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.black)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color(.systemGray5)))
        }
    }
}

#Preview {
    NavigationStack {
        TextSizeView()
    }
}
