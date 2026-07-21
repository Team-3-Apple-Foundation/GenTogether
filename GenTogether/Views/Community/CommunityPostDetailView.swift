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
    let post: CommunityPost

    @StateObject private var commentsViewModel: CommunityCommentsViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel

    init(post: CommunityPost) {
        self.post = post
        _commentsViewModel = StateObject(wrappedValue: CommunityCommentsViewModel(postId: post.id ?? ""))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(post.displayName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text(post.content)
                        .font(.title3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))

                Divider()

                Text("Comments").font(.headline)

                if let errorMessage = commentsViewModel.errorMessage {
                    Text(errorMessage).font(.footnote).foregroundStyle(.red)
                }

                if commentsViewModel.comments.isEmpty {
                    Text("No comments yet — be the first to reply.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 0) {
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
                            Divider()
                        }
                    }
                }

                HStack(spacing: 8) {
                    TextField("Add a comment…", text: $commentsViewModel.draftContent)
                        .textFieldStyle(.roundedBorder)
                    Button("Post") {
                        Task {
                            guard let userId = authViewModel.currentUserId else { return }
                            await commentsViewModel.addComment(userId: userId, displayName: authViewModel.displayName ?? "Member")
                        }
                    }
                    .disabled(!authViewModel.isAuthenticated || commentsViewModel.draftContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
        }
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { commentsViewModel.startObserving() }
        .onDisappear { commentsViewModel.stopObserving() }
    }
}

private struct CommentRow: View {
    let comment: CommunityComment
    let isOwnComment: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(comment.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
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
        .padding(.vertical, 6)
    }
}

#Preview {
    NavigationStack {
        CommunityPostDetailView(
            post: CommunityPost(
                id: "sample",
                userId: "u1",
                displayName: "Sample User",
                communityQuestionId: "q1",
                content: "Sample post content for preview.",
                createdAt: Date(),
                updatedAt: Date()
            )
        )
        .environmentObject(AuthViewModel())
    }
}
