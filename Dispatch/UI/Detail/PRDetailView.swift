import SwiftUI

struct PRDetailView: View {
    let pr: PullRequest
    var onRefresh: () -> Void = {}

    @Environment(DataStore.self) private var dataStore
    @State private var showResolved: Bool = false

    private let builder = CommentThreadBuilder()

    // Computed from DataStore directly — SwiftUI observation auto-tracks
    // dataStore.pullRequests, so this re-renders whenever the polling engine
    // delivers new data (no manual refresh needed for arriving comments).
    private var currentPR: PullRequest {
        dataStore.pullRequests.first(where: { $0.id == pr.id }) ?? pr
    }

    private var displayItems: [CommentThreadBuilder.DisplayItem] {
        builder.build(from: currentPR, showResolvedThreads: showResolved)
    }

    private var resolvedCount: Int {
        currentPR.reviewThreads.filter { $0.isResolved && !$0.comments.isEmpty }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            navigationBar
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    prSummaryHeader
                    Divider()
                    contentArea
                }
            }
        }
        .frame(width: 480)
        .frame(minHeight: 300, maxHeight: 640)
        .background(.regularMaterial)
        .onAppear {
            dataStore.markAsRead(pr)
        }
    }

    // MARK: - Navigation bar

    private var navigationBar: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(pr.repoFullName)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text("#\(pr.number) \(pr.title)")
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
            }

            Spacer()

            if dataStore.isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                // Triggers a real GitHub API poll — detail view auto-updates
                // when DataStore.pullRequests changes (no extra state needed).
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .help("Fetch latest comments from GitHub")
            }

            Button(action: { NSWorkspace.shared.open(pr.url) }) {
                Label("Open in GitHub", systemImage: "arrow.up.forward.square")
                    .font(.system(size: 11))
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - PR summary header

    private var prSummaryHeader: some View {
        HStack(spacing: 8) {
            AvatarView(url: pr.author.avatarURL, size: 24)
            Text(pr.author.login)
                .font(.system(size: 11, weight: .medium))
            Text("·")
                .foregroundStyle(.tertiary)
            Text(pr.createdAt, style: .relative)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            ReviewBadge(state: pr.overallReviewState)
            CIBadge(status: pr.ciStatus)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.secondary.opacity(0.04))
    }

    // MARK: - Content area

    @ViewBuilder
    private var contentArea: some View {
        if let copilotReview = builder.copilotReview(from: currentPR) {
            let copilotThreads = builder.copilotThreads(from: currentPR)
            CopilotReviewSection(review: copilotReview, inlineThreadCount: copilotThreads.count)
                .padding(.top, 8)
            Divider().padding(.top, 4)
        }

        if displayItems.isEmpty && resolvedCount == 0 {
            emptyCommentsState
        } else {
            VStack(alignment: .leading, spacing: 0) {
                // Section header with resolved toggle
                HStack {
                    Text("COMMENTS (\(displayItems.count))")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if resolvedCount > 0 {
                        Button(action: { withAnimation { showResolved.toggle() } }) {
                            Label(
                                showResolved
                                    ? "Hide \(resolvedCount) resolved"
                                    : "Show \(resolvedCount) resolved",
                                systemImage: showResolved ? "eye.slash" : "eye"
                            )
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 4)

                if displayItems.isEmpty {
                    // All threads are resolved and hidden
                    HStack {
                        Spacer()
                        Text("\(resolvedCount) resolved thread\(resolvedCount == 1 ? "" : "s") — tap Show resolved to view")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Spacer()
                    }
                    .padding(.vertical, 16)
                } else {
                    ForEach(displayItems) { item in
                        itemView(for: item)
                        if item.id != displayItems.last?.id {
                            Divider().padding(.horizontal, 12)
                        }
                    }
                    .padding(.bottom, 12)
                }
            }
        }
    }

    @ViewBuilder
    private func itemView(for item: CommentThreadBuilder.DisplayItem) -> some View {
        switch item {
        case .generalComment(let comment):
            CommentRowView(author: comment.author, commentBody: comment.body, date: comment.createdAt)
        case .reviewSummary(let review):
            ReviewSummaryRow(review: review)
        case .inlineThread(let thread):
            ReviewThreadView(thread: thread)
        }
    }

    private var emptyCommentsState: some View {
        VStack(spacing: 8) {
            Image(systemName: "bubble.left")
                .font(.system(size: 24))
                .foregroundStyle(.tertiary)
            Text("No comments yet")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}
