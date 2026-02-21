import SwiftUI

struct PopoverView: View {
    @Environment(DataStore.self) private var dataStore
    var onOpenDetail: (PullRequest) -> Void = { _ in }
    var onOpenPreferences: () -> Void = {}
    var onClosePopover: () -> Void = {}
    var onRefresh: () -> Void = {}

    private let builder = CommentThreadBuilder()

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            if dataStore.monitoredRepositories.isEmpty && !dataStore.isLoading {
                emptySetupState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        statusBanner
                        reviewRequestsSection
                        openPRsSection
                        ciHealthSection
                    }
                }
            }
        }
        .frame(width: 360)
        .frame(minHeight: 200, maxHeight: 520)
        .background(.regularMaterial)
    }

    // MARK: - Header
    private var headerBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Dispatch")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            if let date = dataStore.lastPollDate {
                Text("Updated \(date, style: .relative)")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            // Refresh button — shows spinner while loading
            Button(action: onRefresh) {
                if dataStore.isLoading {
                    ProgressView().controlSize(.mini).frame(width: 12, height: 12)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .help("Refresh now")
            .disabled(dataStore.isLoading)

            Button(action: onOpenPreferences) {
                Image(systemName: "gear")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Preferences")

            Button(action: onClosePopover) {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Status banner
    @ViewBuilder
    private var statusBanner: some View {
        if dataStore.tokenExpired {
            StatusBanner(
                icon: "exclamationmark.triangle.fill",
                message: "GitHub token expired",
                color: .red,
                action: onOpenPreferences,
                actionLabel: "Reconnect"
            )
        } else if dataStore.isOffline {
            StatusBanner(
                icon: "wifi.slash",
                message: "Offline — cached data shown",
                color: .orange,
                action: nil, actionLabel: nil
            )
        }
    }

    // MARK: - Your Review Requests
    @ViewBuilder
    private var reviewRequestsSection: some View {
        if !dataStore.reviewRequests.isEmpty {
            SectionHeader(title: "YOUR REVIEW REQUESTS", count: dataStore.reviewRequests.count)
            ForEach(dataStore.reviewRequests) { pr in
                PendingReviewRow(pr: pr) { onOpenDetail(pr) }
                Divider().padding(.leading, 42)
            }
        }
    }

    // MARK: - Open Pull Requests
    @ViewBuilder
    private var openPRsSection: some View {
        if !dataStore.pullRequests.isEmpty {
            SectionHeader(title: "OPEN PULL REQUESTS")
            let grouped = Dictionary(grouping: dataStore.pullRequests, by: \.repoFullName)
            let sortedRepos = grouped.keys.sorted()
            ForEach(sortedRepos, id: \.self) { repoName in
                if let prs = grouped[repoName] {
                    repoGroup(repoName: repoName, prs: prs)
                }
            }
        } else if !dataStore.monitoredRepositories.isEmpty {
            emptyPRState
        }
    }

    private func repoGroup(repoName: String, prs: [PullRequest]) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(repoName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(.secondary.opacity(0.05))

            ForEach(prs) { pr in
                PRRowView(pr: pr, unreadCount: dataStore.unreadCommentCount(for: pr)) {
                    onOpenDetail(pr)
                }
                Divider().padding(.leading, 46)
            }
        }
    }

    // MARK: - CI Health
    @ViewBuilder
    private var ciHealthSection: some View {
        if !dataStore.ciRuns.isEmpty {
            SectionHeader(title: "CI HEALTH")
            ForEach(dataStore.ciRuns) { ci in
                CIRowView(ci: ci) {
                    if let url = ci.url { NSWorkspace.shared.open(url) }
                }
                Divider().padding(.leading, 26)
            }
        }
    }

    // MARK: - Empty states
    private var emptySetupState: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("No Repositories")
                .font(.headline)
            Text("Add a repository to start monitoring PRs and CI status.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Open Preferences") { onOpenPreferences() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }

    private var emptyPRState: some View {
        HStack {
            Spacer()
            Text("No open pull requests")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.vertical, 16)
    }
}

// MARK: - Helper views
struct SectionHeader: View {
    let title: String
    var count: Int? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            if let count = count {
                Text("\(count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(.secondary.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

struct StatusBanner: View {
    let icon: String
    let message: String
    let color: Color
    let action: (() -> Void)?
    let actionLabel: String?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.system(size: 12))
            Text(message)
                .font(.system(size: 11))
            Spacer()
            if let action = action, let label = actionLabel {
                Button(label, action: action)
                    .font(.system(size: 11))
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.08))
    }
}

struct AvatarView: View {
    let url: URL
    let size: CGFloat

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            case .failure, .empty:
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundStyle(.secondary)
            @unknown default:
                Color.secondary.opacity(0.3)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}
