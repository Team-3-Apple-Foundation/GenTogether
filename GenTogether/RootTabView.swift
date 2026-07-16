//
//  RootTabView.swift
//  GenTogether
//
//  Created by Emily Chen on 16/7/2026.
//

import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            JourneyView()
                .tabItem {
                    Label("Journey", systemImage: "star")
                }

            CommunityView()
                .tabItem {
                    Label("Community", systemImage: "person.2")
                }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
        }
        .tint(.orange) // selected tab tint, matches the app's accent color
    }
}

#Preview {
    RootTabView()
}
