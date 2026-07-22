//
//  CommunityView.swift
//  GenTogether
//

import SwiftUI

struct CommunityView: View {
    @StateObject private var viewModel = CommunityViewModel()
    @EnvironmentObject private var authViewModel: AuthViewModel
    @FocusState private var isComposerFocused: Bool
    @State private var pendingDeletePost: CommunityPost?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                GTHeader(title: "Community")

                ScrollView {
                    VStack(spacing: 20) {
                        composer

                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)
                        }

                        if viewModel.isEmpty {
                            ContentUnavailableView(
                                "No posts yet",
                                systemImage: "bubble.left.and.bubble.right",
                                description: Text("Be the first to share something with the community.")
                            )
                            .padding(.top, 40)
                        } else {
                            LazyVStack(spacing: 14) {
                                ForEach(viewModel.posts) { post in
                                    NavigationLink {
                                        CommunityPostDetailView(post: post)
                                    } label: {
                                        postCard(post)
                                    }
                                    .buttonStyle(.plain)
                                    .task { await viewModel.loadCommentCount(for: post) }
                                    // Long-press to delete — only attached at
                                    // all when this post is the signed-in
                                    // user's own, so someone else's post
                                    // shows no delete option whatsoever.
                                    .modifier(
                                        OwnPostDeleteMenu(
                                            isOwnPost: post.userId == authViewModel.currentUserId,
                                            onDelete: { pendingDeletePost = post }
                                        )
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.vertical, 20)
                }
                .background(GTColor.background)
                .refreshable { await viewModel.load() }
                .task { await viewModel.load() }
            }
            .background(GTColor.background)
            .confirmationDialog(
                "Delete this post?",
                isPresented: Binding(
                    get: { pendingDeletePost != nil },
                    set: { isPresented in if !isPresented { pendingDeletePost = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let post = pendingDeletePost, let userId = authViewModel.currentUserId {
                        Task { await viewModel.deletePost(post, userId: userId) }
                    }
                    pendingDeletePost = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingDeletePost = nil
                }
            } message: {
                Text("This can't be undone.")
            }
        }
    }

    // MARK: Composer

    private var isDraftEmpty: Bool {
        viewModel.draftContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Share with the community")
                .font(.headline)

            TextEditor(text: $viewModel.draftContent)
                .frame(minHeight: 90)
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(GTColor.brand.opacity(0.6), lineWidth: 1)
                )
                .focused($isComposerFocused)

            Button {
                Task {
                    guard let userId = authViewModel.currentUserId else { return }
                    await viewModel.createPost(
                        userId: userId,
                        displayName: authViewModel.displayName ?? "Member"
                    )
                    // Only dismiss the keyboard once the post actually went
                    // through — a failed post leaves the draft (and focus)
                    // in place so the user doesn't lose what they typed.
                    if viewModel.errorMessage == nil {
                        isComposerFocused = false
                    }
                }
            } label: {
                Text("Post")
                    .font(.headline)
                    .foregroundStyle(isDraftEmpty ? Color.secondary : Color.black)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            // Explicit color swap (not just relying on .disabled's automatic
            // dimming) so "can't post yet" vs. "ready to post" reads clearly
            // even at a glance — plain gray vs. brand orange.
            .tint(isDraftEmpty ? Color(.systemGray5) : GTColor.brand)
            .disabled(!authViewModel.isAuthenticated || isDraftEmpty)
        }
        .padding(16)
        .gtCardBackground()
        .padding(.horizontal, 20)
    }

    // MARK: Post card

    private func postCard(_ post: CommunityPost) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                avatar(for: post.displayName)
                Text(post.displayName)
                    .font(.subheadline.weight(.bold))
                Spacer()
                Text(post.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(Color(.systemGray2))
            }

            Text(post.content)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 16) {
                Button {
                    Task {
                        guard let userId = authViewModel.currentUserId else { return }
                        await viewModel.toggleLike(post, userId: userId)
                    }
                } label: {
                    let liked = authViewModel.currentUserId.map(post.isLiked(by:)) ?? false
                    CommunityStatBadge(
                        icon: liked ? "heart.fill" : "heart",
                        count: post.likeCount,
                        tint: liked ? .red : .secondary
                    )
                }
                .buttonStyle(.plain)

                CommunityStatBadge(
                    icon: "bubble.right",
                    count: viewModel.commentCounts[post.id ?? ""] ?? 0,
                    tint: .secondary
                )

                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }

    /// Circular brand-orange avatar showing the display name's first
    /// letter — more identifiable at a glance than a generic person icon.
    private func avatar(for displayName: String) -> some View {
        Circle()
            .fill(GTColor.brand)
            .frame(width: 36, height: 36)
            .overlay(
                Text(displayName.prefix(1).uppercased())
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
            )
    }

}

/// Attaches a long-press "Delete Post" context menu only when `isOwnPost`
/// is true — someone else's post gets no context menu at all, rather than
/// an empty one, so long-pressing it visibly does nothing.
private struct OwnPostDeleteMenu: ViewModifier {
    let isOwnPost: Bool
    let onDelete: () -> Void

    func body(content: Content) -> some View {
        if isOwnPost {
            content.contextMenu {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete Post", systemImage: "trash")
                }
            }
        } else {
            content
        }
    }
}

/// A tight icon + count pairing for a post's like/comment stats. Shared
/// between the Community feed's post cards and a post's detail screen so
/// both use the exact same compact layout rather than two near-identical
/// one-off versions.
struct CommunityStatBadge: View {
    let icon: String
    let count: Int
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.subheadline)
            Text("\(count)")
                .font(.subheadline)
        }
        .foregroundStyle(tint)
    }
}

#Preview {
    CommunityView().environmentObject(AuthViewModel())
}
