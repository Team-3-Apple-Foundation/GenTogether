//
//  GTHeader.swift
//  GenTogether
//
//  The brown branded bar shown at the top of the main screens. One shared
//  component so Home, Journey, and Game all look identical. Optional
//  leading / trailing buttons (a back chevron, a Reset button, …) sit at
//  the edges while the title stays centered.
//

import SwiftUI

struct GTHeader: View {
    let title: String
    var leading: AnyView? = nil
    var trailing: AnyView? = nil
    /// The bar's fill. Defaults to the brand orange; pass `.clear` for a
    /// header with no coloured background.
    var background: Color = GTColor.brand

    var body: some View {
        ZStack {
            Text(title)
                .font(.title.bold())

            HStack {
                if let leading { leading }
                Spacer()
                if let trailing { trailing }
            }
        }
        .foregroundStyle(.black)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 20)
        .background(background.ignoresSafeArea(edges: .top))
    }
}
