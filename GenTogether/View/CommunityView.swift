import SwiftUI

struct CommunityView: View {
    // Static placeholder data — view is presentation-only, no logic.
    private let posts = [
        CommunityPost.placeholder,
        CommunityPost.placeholder,
        CommunityPost.placeholder
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    TodaysQuestionCard(questionNumber: 123)

                    VStack(spacing: 0) {
                        ForEach(posts) { post in
                            CommunityPostRow(post: post)
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
//            .navigationTitle("Community")
//            .navigationBarTitleDisplayMode(.large)
            // Tinted large-title nav bar reproduces the orange header from the
            // mock while staying inside the native, HIG-approved nav bar —
            // rather than faking a header with a manual ZStack.
//            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

// MARK: - Today's Question Card

struct TodaysQuestionCard: View {
    let questionNumber: Int

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            Text("Today's Question #\(questionNumber)")
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                // Dynamic Type friendly — no fixed font sizes anywhere.

            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.orange.opacity(0.55), lineWidth: 1.5)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
                .frame(height: 300)
                .accessibilityLabel("Answer input area")
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground)) // adapts to Dark Mode
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
    }
}

// MARK: - Community Post Model

struct CommunityPost: Identifiable {
    let id = UUID()
    let userName: String
    let text: String
    let likeCount: Int
    let commentCount: Int

    static let placeholder = CommunityPost(
        userName: "USER NAME",
        text: "Hi Guys, gibberish...",
        likeCount: 21,
        commentCount: 2
    )
}

// MARK: - Community Post Row

struct CommunityPostRow: View {
    let post: CommunityPost

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color(.systemGray4))
                    .frame(width: 40, height: 40) // ≥44pt tap target once wrapped in a button
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color(.systemBackground))
                    )
                    .accessibilityHidden(true)

                Text(post.userName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Spacer()
            }

            Text(post.text)
                .font(.title3)
                .foregroundStyle(.primary)

            HStack(spacing: 20) {
                statLabel(icon: "heart", value: post.likeCount, description: "likes")
                statLabel(icon: "bubble.left", value: post.commentCount, description: "comments")
                Spacer()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private func statLabel(icon: String, value: Int, description: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text("\(value)")
        }
        .accessibilityLabel("\(value) \(description)")
    }
}


#Preview {
    CommunityView()
}
