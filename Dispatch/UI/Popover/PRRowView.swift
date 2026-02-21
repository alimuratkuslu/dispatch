import SwiftUI

struct PRRowView: View {
    let pr: PullRequest
    let unreadCount: Int
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Main row — opens detail panel
            Button(action: onTap) {
                HStack(spacing: 8) {
                    AvatarView(url: pr.author.avatarURL, size: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            if pr.isDraft {
                                Text("DRAFT")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 4).padding(.vertical, 1)
                                    .background(.secondary.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                            }
                            Text(pr.title)
                                .lineLimit(1)
                                .font(.system(size: 12, weight: .medium))
                        }

                        HStack(spacing: 4) {
                            Text("#\(pr.number)")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            ReviewBadge(state: pr.overallReviewState)
                            CIBadge(status: pr.ciStatus)
                            Spacer()
                            if unreadCount > 0 {
                                Label("\(unreadCount)", systemImage: "bubble.left.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.blue)
                            }
                            Text(pr.updatedAt, style: .relative)
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Open in GitHub button
            Button {
                NSWorkspace.shared.open(pr.url)
            } label: {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .help("Open in GitHub")
            .padding(.trailing, 10)
        }
    }
}

struct ReviewBadge: View {
    let state: ReviewState?

    var body: some View {
        if let state = state {
            Text(state.shortLabel)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(state.badgeColor)
                .padding(.horizontal, 4).padding(.vertical, 1)
                .background(state.badgeColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
    }
}

struct CIBadge: View {
    let status: CIStatus

    var body: some View {
        HStack(spacing: 2) {
            Circle()
                .fill(status.dotColor)
                .frame(width: 5, height: 5)
            Text(status.displayName)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Extensions for badges
extension ReviewState {
    var shortLabel: String {
        switch self {
        case .approved: return "Approved"
        case .changesRequested: return "Changes"
        case .commented: return "Commented"
        case .dismissed: return "Dismissed"
        }
    }

    var badgeColor: Color {
        switch self {
        case .approved: return .green
        case .changesRequested: return .orange
        case .commented: return .secondary
        case .dismissed: return .secondary
        }
    }
}

extension CIStatus {
    var dotColor: Color {
        switch self {
        case .passing: return .green
        case .failing: return .red
        case .pending: return .yellow
        case .skipped: return .gray
        case .unknown: return .gray
        }
    }
}
