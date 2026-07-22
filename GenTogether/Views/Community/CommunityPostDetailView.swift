//
//  CommunityPostDetailView.swift
//  GenTogether
//
//  Shows a single community post and its comments (realtime via
//  CommunityCommentsViewModel's snapshot listener), with add/delete for
//  the current user's own comments.
//

import SwiftUI

struct CommunityPostDetailView: View {
    @State private var post: CommunityPost
    @State private var likeErrorMessage: String?

    @StateObject private var commentsViewModel: CommunityCommentsViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    init(post: CommunityPost) {
        _post = State(initialValue: post)
        _commentsViewModel = StateObject(wrappedValue: CommunityCommentsViewModel(postId: post.id ?? ""))
    }

    private var isDraftEmpty: Bool {
        commentsViewModel.draftContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            GTHeader(
                title: "Post",
                leading: AnyView(
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.black)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(Color(.systemGray5)))
                    }
                )
            )

            ScrollView {
                // No dividers between the post card, "Comments" heading, and
                // each comment card — the cards' own borders already mark
                // where one block ends and the next begins, so a divider on
                // top of that would just be visual noise.
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        authorLabel(post.displayName)
                        Text(post.content)
                            .font(.title3)

                        Button {
                            Task { await toggleLike() }
                        } label: {
                            let liked = authViewModel.currentUserId.map(post.isLiked(by:)) ?? false
                            CommunityStatBadge(
                                icon: liked ? "heart.fill" : "heart",
                                count: post.likeCount,
                                tint: liked ? .red : .secondary
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.systemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color(.systemGray5), lineWidth: 1)
                    )

                    if let likeErrorMessage {
                        Text(likeErrorMessage).font(.footnote).foregroundStyle(.red)
                    }

                    Text("Comments").font(.headline)

                    if let errorMessage = commentsViewModel.errorMessage {
                        Text(errorMessage).font(.footnote).foregroundStyle(.red)
                    }

                    if commentsViewModel.comments.isEmpty {
                        Text("No comments yet — be the first to reply.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(commentsViewModel.comments) { comment in
                                CommentRow(
                                    comment: comment,
                                    isOwnComment: comment.userId == authViewModel.currentUserId,
                                    onDelete: {
                                        Task {
                                            guard let userId = authViewModel.currentUserId else { return }
                                            await commentsViewModel.deleteComment(comment, userId: userId)
                                        }
                                    }
                                )
                            }
                        }
                    }

                    // Same rounded/brand-bordered look as the composer's
                    // text box on the list screen, so the two "write
                    // something" moments in Community feel like one system.
                    HStack(spacing: 8) {
                        TextField("Add a comment…", text: $commentsViewModel.draftContent)
                            .padding(10)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(GTColor.brand.opacity(0.6), lineWidth: 1)
                            )

                        Button("Post") {
                            Task {
                                guard let userId = authViewModel.currentUserId else { return }
                                await commentsViewModel.addComment(userId: userId, displayName: authViewModel.displayName ?? "Member")
                            }
                        }
                        .foregroundStyle(isDraftEmpty ? Color.secondary : Color.black)
                        .buttonStyle(.borderedProminent)
                        .tint(isDraftEmpty ? Color(.systemGray5) : GTColor.brand)
                        .disabled(!authViewModel.isAuthenticated || isDraftEmpty)
                    }
                }
                .padding()
            }
            .background(GTColor.background)
        }
        .background(GTColor.background)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { commentsViewModel.startObserving() }
        .onDisappear { commentsViewModel.stopObserving() }
    }

    /// Same optimistic-update-then-reconcile pattern as
    /// `CommunityViewModel.toggleLike`, just scoped to this one already-in-
    /// hand post instead of looking it up in a list.
    private func toggleLike() async {
        guard let userId = authViewModel.currentUserId, let postId = post.id else { return }
        let isLiked = post.isLiked(by: userId)
        likeErrorMessage = nil

        if isLiked {
            post.likedBy.removeAll { $0 == userId }
        } else {
            post.likedBy.append(userId)
        }

        do {
            try await CommunityService.shared.toggleLike(postId: postId, userId: userId, isCurrentlyLiked: isLiked)
        } catch {
            if isLiked {
                post.likedBy.append(userId)
            } else {
                post.likedBy.removeAll { $0 == userId }
            }
            likeErrorMessage = error.localizedDescription
        }
    }
}

/// The small-caps gray author tag used above both the main post's content
/// and every comment's content, so the two read as the same visual family.
private func authorLabel(_ name: String) -> some View {
    Text(name)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .textCase(.uppercase)
}

private struct CommentRow: View {
    let comment: CommunityComment
    let isOwnComment: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                authorLabel(comment.displayName)
                Text(comment.content)
                    .font(.body)
            }
            Spacer()
            if isOwnComment {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
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
}

#Preview {
    NavigationStack {
        CommunityPostDetailView(
            post: CommunityPost(
                id: "sample",
                userId: "u1",
                displayName: "Sample User",
                content: "Sample post content for preview.",
                createdAt: Date(),
                updatedAt: Date()
            )
        )
        .environmentObject(AuthViewModel())
    }
}
