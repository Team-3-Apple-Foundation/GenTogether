//
//  GenTogetherApp.swift
//  GenTogether
//
//  Created by Emily Chen on 16/7/2026.
//

import SwiftUI

@main
struct GenTogetherApp: App {
    
    @State private var progress = GameProgress()
    
    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(progress)
        }
    }
}

