
import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            NavigationLink {
                GameView(challenge: Challenge.samples[2])
            } label: {
                Label("Today's game", systemImage: "play.fill")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.borderedProminent)
            .padding(20)
            .navigationTitle("Home")
        }
    }
}

#Preview {
    HomeView()
}
