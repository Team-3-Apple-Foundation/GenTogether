//
//  GTTabBar.swift
//  GenTogether
//
//  Custom bottom tab bar: the stock TabView chrome doesn't match the
//  design reference closely enough (icon weight/style switching between
//  outline and filled per tab, custom spacing), so RootTabView drives
//  navigation itself and just renders this for the bar.
//

import SwiftUI

enum GTTab: CaseIterable {
    case home
    case journey
    case community
    case profile

    var title: String {
        switch self {
        case .home: "Home"
        case .journey: "Journey"
        case .community: "Community"
        case .profile: "Profile"
        }
    }

    var filledIcon: String {
        switch self {
        case .home: "house.fill"
        case .journey: "star.fill"
        case .community: "message.fill"
        case .profile: "person.fill"
        }
    }

    var outlineIcon: String {
        switch self {
        case .home: "house"
        case .journey: "star"
        case .community: "message"
        case .profile: "person"
        }
    }
}

struct GTTabBar: View {
    @Binding var selected: GTTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(GTTab.allCases, id: \.self) { tab in
                let isSelected = tab == selected

                Button {
                    selected = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: isSelected ? tab.filledIcon : tab.outlineIcon)
                            .font(.system(size: 22, weight: isSelected ? .semibold : .regular))
                        Text(tab.title)
                            .font(.caption2)
                            .fontWeight(isSelected ? .semibold : .regular)
                    }
                    .foregroundStyle(isSelected ? GTColor.brand : Color.gray)
                    // Soft orange pill sits behind the selected tab only.
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(GTColor.brand.opacity(0.16))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        // The floating capsule: rounded, with an all-around shadow.
        .background(
            Capsule(style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.12), radius: 14, x: 0, y: 6)
        )
        // Margins from the screen edges so the bar visibly floats.
        .padding(.horizontal, 16)
        // Negative bottom padding pushes the bar down into the home-indicator
        // safe area for a more grounded look, while staying clear of the line.
        .padding(.bottom, -16)
    }
}

#Preview {
    @Previewable @State var selected: GTTab = .home
    VStack {
        Spacer()
        GTTabBar(selected: $selected)
    }
    .background(GTColor.background)
}
