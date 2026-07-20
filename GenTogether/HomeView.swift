
import SwiftUI

struct HomeView: View {
    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Learn to identify Generative AI!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 20)

                    InfoCard(
                        iconName: "checkmark",
                        iconColor: GTColor.success,
                        iconBackground: GTColor.successSoft,
                        title: "7 out of 10 Correct",
                        body: "Last game played."
                    )

                    InfoCard(
                        iconName: "lightbulb.fill",
                        iconColor: GTColor.tip,
                        iconBackground: GTColor.tipSoft,
                        title: "Tip of the Day",
                        body: "AI-generated images often struggle with hands, text, and repeating background patterns — look closely before you decide."
                    )

                    Spacer(minLength: 12)

                    playButton
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(GTColor.background)
        }
        .background(GTColor.background)
    }

    private var header: some View {
        Text("GenTogether")
            .font(.title.bold())
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .padding(.bottom, 20)
            .background(GTColor.brand.ignoresSafeArea(edges: .top))
    }

    private var playButton: some View {
        Button {
            // Navigate to the "spot the difference" game.
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .bold))
                Text("Play spot the difference")
                    .font(.body.bold())
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(GTColor.brand)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeView()
}
