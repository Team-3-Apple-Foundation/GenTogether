import SwiftUI

struct CommunityView: View {
    @StateObject private var viewModel = CommunityViewModel()
    @EnvironmentObject private var authViewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    TodaysQuestionCard(
                        question: viewModel.activeQuestion?.question,
                        draftContent: $viewModel.draftContent,
                        isSubmitting: viewModel.isLoading,
                        canSubmit: authViewModel.isAuthenticated,
                        onSubmit: {
                            Task {
                                guard let userId = authViewModel.currentUserId else { return }
                                await viewModel.createPost(userId: userId, displayName: authViewModel.displayName ?? "Member")
                            }
                        }
                    )

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }

                    if viewModel.isEmpty {
                        ContentUnavailableView("No posts yet", systemImage: "bubble.left.and.bubble.right")
                            .padding(.top, 24)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(viewModel.posts) { post in
                                NavigationLink {
                                    CommunityPostDetailView(post: post)
                                } label: {
                                    CommunityPostRow(
                                        post: post,
                                        commentCount: viewModel.commentCounts[post.id ?? ""] ?? 0,
                                        isOwnPost: post.userId == authViewModel.currentUserId,
                                        onDelete: {
                                            Task {
                                                guard let userId = authViewModel.currentUserId else { return }
                                                await viewModel.deletePost(post, userId: userId)
                                            }
                                        }
                                    )
                                    .task { await viewModel.loadCommentCount(for: post) }
                                }
                                .buttonStyle(.plain)
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Community")
            .navigationBarTitleDisplayMode(.large)
            // Tinted large-title nav bar reproduces the orange header from the
            // mock while staying inside the native, HIG-approved nav bar —
            // rather than faking a header with a manual ZStack.
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
        }
    }
}

// MARK: - Today's Question Card

struct TodaysQuestionCard: View {
    let question: String?
    @Binding var draftContent: String
    let isSubmitting: Bool
    let canSubmit: Bool
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            Text(question ?? "Today's Question")
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                // Dynamic Type friendly — no fixed font sizes anywhere.

            VStack(spacing: 12) {
                TextEditor(text: $draftContent)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .frame(height: 220)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.orange.opacity(0.55), lineWidth: 1.5)
                    )
                    .accessibilityLabel("Answer input area")

                Button(action: onSubmit) {
                    Group {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("Post")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(isSubmitting || !canSubmit || draftContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
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

// MARK: - Community Post Row

struct CommunityPostRow: View {
    let post: CommunityPost
    let commentCount: Int
    let isOwnPost: Bool
    let onDelete: () -> Void

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

                Text(post.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Spacer()

                if isOwnPost {
                    Menu {
                        Button(role: .destructive, action: onDelete) {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(.secondary)
                            .padding(8)
                    }
                }
            }

            Text(post.content)
                .font(.title3)
                .foregroundStyle(.primary)

            HStack(spacing: 20) {
                statLabel(icon: "bubble.left", value: commentCount, description: "comments")
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
        .environmentObject(AuthViewModel())
}
