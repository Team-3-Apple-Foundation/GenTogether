//
//  RootTabView.swift
//  GenTogether
//
//  Created by Emily Chen on 16/7/2026.
//

import SwiftUI

/// The tabs, named. An enum means we can only ever point at a real tab —
/// there's no way to typo "jorney" and have it compile.
enum AppTab {
    case home, journey, community, profile
}

struct RootTabView: View {
    /// Which tab is showing. Home lends this to its Play button so it can
    /// switch us over to Journey.
    @State private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(AppTab.home)

            JourneyView()
                .tabItem {
                    Label("Journey", systemImage: "star")
                }
                .tag(AppTab.journey)

            CommunityView()
                .tabItem {
                    Label("Community", systemImage: "person.2")
                }
                .tag(AppTab.community)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
                .tag(AppTab.profile)
        }
        .tint(.orange) // selected tab tint, matches the app's accent color
    }
}

#Preview {
    RootTabView()
}
