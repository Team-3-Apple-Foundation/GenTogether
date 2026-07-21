
import SwiftUI

struct HomeView: View {
    /// Borrowed from RootTabView so Play can switch us to the Journey tab.
    @Binding var selectedTab: AppTab

    var body: some View {
        NavigationStack {
            Button {
                selectedTab = .journey
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
    HomeView(selectedTab: .constant(.home))
}
