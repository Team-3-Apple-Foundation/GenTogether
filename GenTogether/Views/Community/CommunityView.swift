//
//  CommunityView.swift
//  GenTogether
//

import SwiftUI

struct CommunityView: View {
    @StateObject private var viewModel = CommunityViewModel()
    @EnvironmentObject private var authViewModel: AuthViewModel

    var body: some View {
        NavigationStack {
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
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.vertical, 20)
            }
            .navigationTitle("Community")
            .background(Color(.systemGroupedBackground))
            .refreshable { await viewModel.load() }
            .task { await viewModel.load() }
        }
    }

    // MARK: Composer

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
                        .stroke(.orange.opacity(0.5), lineWidth: 1)
                )

            Button {
                Task {
                    guard let userId = authViewModel.currentUserId else { return }
                    await viewModel.createPost(
                        userId: userId,
                        displayName: authViewModel.displayName ?? "Member"
                    )
                }
            } label: {
                Text("Post")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(
                !authViewModel.isAuthenticated ||
                viewModel.draftContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }

    // MARK: Post card

    private func postCard(_ post: CommunityPost) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "person.crop.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Text(post.displayName)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(post.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(post.content)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 20) {
                Button {
                    Task {
                        guard let userId = authViewModel.currentUserId else { return }
                        await viewModel.toggleLike(post, userId: userId)
                    }
                } label: {
                    let liked = authViewModel.currentUserId.map(post.isLiked(by:)) ?? false
                    Label("\(post.likeCount)", systemImage: liked ? "heart.fill" : "heart")
                        .font(.subheadline)
                        .foregroundStyle(liked ? .red : .secondary)
                }
                .buttonStyle(.plain)

                Label("\(viewModel.commentCounts[post.id ?? ""] ?? 0)",
                      systemImage: "bubble.right")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()
            }
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    CommunityView().environmentObject(AuthViewModel())
}
