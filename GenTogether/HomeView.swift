
import SwiftUI

struct HomeView: View {
    /// Set true when the tutorial's "Start game" is tapped, which pushes Journey.
    @State private var showJourneyFromTutorial = false

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
                    tutorialButton
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(GTColor.background)
        }
        .background(GTColor.background)
        .navigationDestination(isPresented: $showJourneyFromTutorial) {
            JourneyView()
                .navigationBarBackButtonHidden(true)
        }
    }

    private var header: some View {
        GTHeader(title: "GenTogether")
    }
    
    private var tutorialButton: some View {
        NavigationLink {
            TutorialSlide(onStartGame: { showJourneyFromTutorial = true })
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 18, weight: .bold))
                Text("How to play")
                    .font(.body.bold())
            }
            .foregroundStyle(GTColor.brand2)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(GTColor.brand2, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
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
            .foregroundStyle(.white)
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
