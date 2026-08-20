//
//  CommunityView.swift
//  GenTogether
//

import SwiftUI

struct CommunityView: View {
    @StateObject private var viewModel = CommunityViewModel()
    @EnvironmentObject private var authViewModel: AuthViewModel
    @FocusState private var isComposerFocused: Bool

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
                                        CommunityPostRow(
                                            post: post,
                                            isOwnPost: post.userId == authViewModel.currentUserId,
                                            isLiked: authViewModel.currentUserId.map(post.isLiked(by:)) ?? false,
                                            commentCount: viewModel.commentCounts[post.id ?? ""] ?? 0,
                                            onToggleLike: {
                                                Task {
                                                    guard let userId = authViewModel.currentUserId else { return }
                                                    await viewModel.toggleLike(post, userId: userId)
                                                }
                                            },
                                            onDelete: {
                                                Task {
                                                    guard let userId = authViewModel.currentUserId else { return }
                                                    await viewModel.deletePost(post, userId: userId)
                                                }
                                            }
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .task { await viewModel.loadCommentCount(for: post) }
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

}

/// A single post card in the Community feed.
///
/// This is its own `View` (rather than a plain helper function) so each
/// row owns its own `@State` for the delete-confirmation popover — that's
/// what lets the popover anchor to *this* row's trash button specifically,
/// instead of one confirmation shared across every post in the list.
private struct CommunityPostRow: View {
    let post: CommunityPost
    let isOwnPost: Bool
    let isLiked: Bool
    let commentCount: Int
    let onToggleLike: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                InitialsAvatar(name: post.displayName, diameter: 36)
                Text(post.displayName)
                    .font(.subheadline.weight(.bold))
                Spacer()
                Text(post.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(Color(.systemGray2))

                // Only shown on the signed-in user's own post — someone
                // else's post gets no delete button at all, rather than a
                // disabled one.
                if isOwnPost {
                    Button {
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.subheadline)
                            .foregroundStyle(Color(.systemGray2))
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    // Anchored directly to this button (not to the screen
                    // or the whole list), so it opens right next to the
                    // row that was actually tapped.
                    .popover(isPresented: $showDeleteConfirm) {
                        deleteConfirmation
                            // Without this, iOS collapses the popover into
                            // a bottom sheet on iPhone's compact width —
                            // this keeps the actual floating-bubble look.
                            .presentationCompactAdaptation(.popover)
                    }
                }
            }

            Text(post.content)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 16) {
                Button(action: onToggleLike) {
                    CommunityStatBadge(
                        icon: isLiked ? "heart.fill" : "heart",
                        count: post.likeCount,
                        tint: isLiked ? .red : .secondary
                    )
                }
                .buttonStyle(.plain)

                CommunityStatBadge(
                    icon: "bubble.right",
                    count: commentCount,
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

    private var deleteConfirmation: some View {
        VStack(spacing: 16) {
            Text("Delete this post?")
                .font(.headline)
            Text("This can't be undone.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 12) {
                Button("Cancel", role: .cancel) {
                    showDeleteConfirm = false
                }
                .buttonStyle(.bordered)

                Button("Delete", role: .destructive) {
                    showDeleteConfirm = false
                    onDelete()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
        .padding(20)
        .frame(minWidth: 240)
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
