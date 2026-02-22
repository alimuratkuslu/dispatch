import SwiftUI

struct PopoverView: View {
    @Environment(DataStore.self) private var dataStore
    var onOpenPreferences: () -> Void = {}
    var onClosePopover: () -> Void = {}
    var onRefresh: () -> Void = {}
    var onDetailToggled: ((Bool) -> Void)? = nil
    
    @State private var selectedPR: PullRequest? = nil

    private let builder = CommentThreadBuilder()

    var body: some View {
        VStack(spacing: 0) {
            if let pr = selectedPR {
                detailView(for: pr)
            } else {
                listView
            }
        }
        .frame(width: selectedPR == nil ? 360 : 480)
        .frame(minHeight: 200, maxHeight: selectedPR == nil ? 600 : 720)
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow).ignoresSafeArea())
        .onChange(of: selectedPR != nil) { _, isDetail in
            onDetailToggled?(isDetail)
        }
    }

    private var listView: some View {
        VStack(spacing: 0) {
            headerBar
            Divider().opacity(0.1)
            
            if dataStore.monitoredRepositories.isEmpty && !dataStore.isLoading {
                VStack {
                    emptySetupState
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        statusBanner
                        reviewRequestsSection
                        openPRsSection
                        ciHealthSection
                    }
                    .padding(.bottom, 20)
                }
                .scrollIndicators(.never)
            }
        }
    }

    private func detailView(for pr: PullRequest) -> some View {
        PRDetailView(
            pr: pr,
            onRefresh: onRefresh,
            onBack: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    selectedPR = nil
                }
            }
        )
    }

    // MARK: - Header
    private var headerBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.primary)
            
            Text("Dispatch")
                .font(.system(size: 15, weight: .bold, design: .default))
                .tracking(-0.3)
            
            Spacer()
            
            if let date = dataStore.lastPollDate {
                Text("Updated \(date, style: .relative)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            
            HStack(spacing: 4) {
                Button(action: onRefresh) {
                    if dataStore.isLoading {
                        ProgressView().controlSize(.mini).scaleEffect(0.7)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
                .opacity(dataStore.isLoading ? 1 : 0.6)
                
                Button(action: onOpenPreferences) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
                .opacity(0.6)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
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

    // MARK: - Review Requests
    @ViewBuilder
    private var reviewRequestsSection: some View {
        if !dataStore.reviewRequests.isEmpty {
            SectionHeader(title: "ACTION REQUIRED", count: dataStore.reviewRequests.count)
            ForEach(dataStore.reviewRequests) { pr in
                PendingReviewRow(pr: pr) { 
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selectedPR = pr
                    }
                }
                Divider().opacity(0.05).padding(.leading, 16)
            }
        }
    }

    // MARK: - Open Pull Requests
    @ViewBuilder
    private var openPRsSection: some View {
        if !dataStore.visiblePullRequests.isEmpty {
            SectionHeader(title: "MONITORED PRs")
            let grouped = Dictionary(grouping: dataStore.visiblePullRequests, by: \.repoFullName)
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
                Text(repoName.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .opacity(0.6)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            ForEach(prs) { pr in
                PRRowView(pr: pr, unreadCount: dataStore.unreadCommentCount(for: pr)) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selectedPR = pr
                    }
                }
                if pr != prs.last {
                    Divider().opacity(0.05).padding(.leading, 16)
                }
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: - CI Health
    @ViewBuilder
    private var ciHealthSection: some View {
        if !dataStore.ciRuns.isEmpty {
            SectionHeader(title: "WORKFLOW HEALTH")
            ForEach(dataStore.ciRuns) { ci in
                CIRowView(ci: ci) {
                    if let url = ci.url { NSWorkspace.shared.open(url) }
                }
                Divider().opacity(0.05).padding(.leading, 16)
            }
        }
    }

    // MARK: - Empty states
    private var emptySetupState: some View {
        VStack(spacing: 16) {
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
        .padding(32)
        .frame(maxWidth: .infinity)
    }

    private var emptyPRState: some View {
        HStack {
            Spacer()
            Text("No open pull requests")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.vertical, 32)
    }
}

// MARK: - Helper views
struct SectionHeader: View {
    let title: String
    var count: Int? = nil

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .default))
                .foregroundStyle(.secondary)
                .tracking(0.5)
            Spacer()
            if let count = count {
                Text("\(count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.blue)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
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
                .font(.system(size: 12, weight: .bold))
            Text(message)
                .font(.system(size: 11, weight: .semibold))
            Spacer()
            if let action = action, let label = actionLabel {
                Button(label, action: action)
                    .font(.system(size: 11, weight: .bold))
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(color.opacity(0.1))
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
        .overlay(Circle().stroke(.primary.opacity(0.1), lineWidth: 0.5))
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
