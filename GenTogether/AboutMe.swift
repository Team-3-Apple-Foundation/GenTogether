//
//  AboutMeFile.swift
//  GenTogether
//
//  Created by Ameya More on 16/7/2026.
//

import Foundation
import SwiftUI

struct AboutView: View {
    var body: some View {


            Text("Ameya M")
                .font(.title)
                .fontWeight(.bold)

            Text("iOS Developer")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Hi! I'm a passionate iOS developer who loves building apps with Swift and SwiftUI.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Text("📧 apple123@icloud.com")
                .foregroundColor(.blue)
        }
    }


#Preview {
    AboutView()
}
