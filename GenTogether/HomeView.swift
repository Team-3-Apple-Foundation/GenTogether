
import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            content
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Learn to identify Generative AI!")
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                        .padding(.top, 20)

                    TabView {
                        ForEach(Tip.samples) { tip in
                            TipCard(tip: tip)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .frame(height: 430)
                    .onAppear {
                        UIPageControl.appearance().currentPageIndicatorTintColor = .black
                        UIPageControl.appearance().pageIndicatorTintColor = UIColor.black.withAlphaComponent(0.25)
                    }

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
        GTHeader(title: "GenTogether")
    }

    private var playButton: some View {
        NavigationLink {
            JourneyView()
                .navigationBarBackButtonHidden(true)
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
            .background(GTColor.brand2)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
}
