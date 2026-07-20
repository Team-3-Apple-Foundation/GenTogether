//
//  RootTabView.swift
//  GenTogether
//
//  Created by Emily Chen on 16/7/2026.
//

import SwiftUI

struct RootTabView: View {
    @State private var selectedTab: GTTab = .home

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch selectedTab {
                case .home: HomeView()
                case .journey: JourneyView()
                case .community: CommunityView()
                case .profile: ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            GTTabBar(selected: $selectedTab)
        }
    }
}

#Preview {
    RootTabView()
}
