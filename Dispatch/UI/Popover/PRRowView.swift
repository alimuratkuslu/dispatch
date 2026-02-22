import SwiftUI

struct PRRowView: View {
    let pr: PullRequest
    let unreadCount: Int
    let onTap: () -> Void
    
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 0) {
            // Main row — opens detail panel
            Button(action: onTap) {
                HStack(spacing: 12) {
                    AvatarView(url: pr.author.avatarURL, size: 30)
                        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            if pr.isDraft {
                                Text("DRAFT")
                                    .font(.system(size: 8, weight: .bold, design: .default))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 4).padding(.vertical, 2)
                                    .background(.secondary.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                            }
                            Text(pr.title)
                                .lineLimit(1)
                                .font(.system(size: 13, weight: .semibold, design: .default))
                                .foregroundStyle(.primary)
                        }

                        HStack(spacing: 6) {
                            Text("#\(pr.number)")
                                .font(.system(size: 11, weight: .medium, design: .default))
                                .foregroundStyle(.secondary)
                            
                            ReviewBadge(state: pr.overallReviewState)
                            CIBadge(status: pr.ciStatus)
                            
                            if pr.mergeable == .conflicting {
                                MergeConflictBadge()
                            }
                            
                            Spacer()
                            
                            if unreadCount > 0 {
                                HStack(spacing: 3) {
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 6))
                                    Text("\(unreadCount)")
                                        .font(.system(size: 11, weight: .bold, design: .default))
                                }
                                .foregroundStyle(.blue)
                            }
                            
                            Text(pr.updatedAt, style: .relative)
                                .font(.system(size: 11, weight: .regular, design: .default))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Open in GitHub button
            Button {
                NSWorkspace.shared.open(pr.url)
            } label: {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .help("Open in GitHub")
            .padding(.trailing, 16)
            .opacity(isHovered ? 1 : 0)
        }
        .background(isHovered ? Color.secondary.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 8)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct ReviewBadge: View {
    let state: ReviewState?

    var body: some View {
        if let state = state {
            Text(state.shortLabel.uppercased())
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(state.badgeColor)
                .padding(.horizontal, 4).padding(.vertical, 1)
                .background(state.badgeColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
    }
}

struct CIBadge: View {
    let status: CIStatus

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(status.dotColor)
                .frame(width: 5, height: 5)
                .shadow(color: status.dotColor.opacity(0.5), radius: 2)
            Text(status.displayName)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

struct MergeConflictBadge: View {
    var body: some View {
        Text("CONFLICT")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 4).padding(.vertical, 1)
            .background(Color.red)
            .clipShape(RoundedRectangle(cornerRadius: 3))
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
