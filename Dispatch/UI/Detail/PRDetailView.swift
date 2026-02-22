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
        .frame(minHeight: 300, maxHeight: 720)
        .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow).ignoresSafeArea())
        .onAppear {
            dataStore.markAsRead(pr)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("com.dispatch.refreshPR"))) { _ in
            onRefresh()
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

            if currentPR.isDraft {
                Button(action: {
                    Task {
                        try? await dataStore.apiClient.markPullRequestReady(id: pr.id)
                        onRefresh()
                    }
                }) {
                    Text("Ready for Review")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.mini)
                .tint(.green)
            } else if pr.author.login == dataStore.viewerLogin && !currentPR.hasCopilotReview {
                Button(action: {
                    Task {
                        let parts = pr.repoFullName.split(separator: "/")
                        guard parts.count == 2 else { return }
                        do {
                            // Post a comment mentioning @copilot to trigger a review.
                            // This works broadly — Copilot responds to @mentions in PR comments.
                            try await dataStore.apiClient.postCopilotReviewComment(
                                owner: String(parts[0]),
                                repo: String(parts[1]),
                                number: pr.number
                            )
                            onRefresh()
                        } catch {
                            print("[AI Review] Failed: \(error.localizedDescription)")
                        }
                    }
                }) {
                    Label("AI Review", systemImage: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.mini)
                .tint(.purple)
            }

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
        Group {
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

            if currentPR.mergeable == .conflicting {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("This branch has merge conflicts that must be resolved.")
                        .font(.system(size: 11, weight: .medium))
                    Spacer()
                Button("Copy Fix Command") {
                    let cmd = "git fetch origin && git checkout \(currentPR.headRefName) && git merge origin/main"
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(cmd, forType: .string)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.red.opacity(0.1))
            .foregroundStyle(.red)
        }

        if currentPR.state == .merged {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                Text("This pull request has been merged!")
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                Button("Copy Cleanup Command") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(currentPR.localCleanupCommand, forType: .string)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.purple.opacity(0.1))
            .foregroundStyle(.purple)
        }

        if currentPR.ciStatus == .failing {
            HStack {
                Image(systemName: "xmark.octagon.fill")
                Text("Checks failed. View logs to debug.")
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                Button("View Logs") {
                    // Logic to find the failing run URL would go here.
                    // For now, we open the PR checks page.
                    NSWorkspace.shared.open(currentPR.url.appendingPathComponent("checks"))
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.red.opacity(0.1))
            .foregroundStyle(.red)
        }
    }
}

    // MARK: - Content area

    @ViewBuilder
    private var contentArea: some View {
        if currentPR.state == .open {
            AISummaryBanner(pr: currentPR)
                .padding(.top, 8)
        }

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

struct AISummaryBanner: View {
    let pr: PullRequest
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.purple)
                Text("DISPATCH AI SUMMARY")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.purple)
                Spacer()
            }
            
            Text(generatePlaceholderSummary())
                .font(.system(size: 11))
                .foregroundStyle(.primary)
                .lineLimit(2)
        }
        .padding(10)
        .background(Color.purple.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 12)
    }
    
    private func generatePlaceholderSummary() -> String {
        let verb = pr.isDraft ? "Drafting" : "Merging"
        return "\(verb) \(pr.headRefName) into main. This PR contains \(pr.allCommentCount) comments and is currently \(pr.ciStatus.displayName.lowercased())."
    }
}
