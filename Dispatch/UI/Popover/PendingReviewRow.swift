import SwiftUI

struct PendingReviewRow: View {
    let pr: PullRequest
    let onTap: () -> Void
    
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                AvatarView(url: pr.author.avatarURL, size: 28)
                    .shadow(color: .black.opacity(0.1), radius: 2, y: 1)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(pr.repoFullName)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                        
                        Text(pr.title)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                            .foregroundStyle(.primary)
                    }
                    
                    HStack(spacing: 4) {
                        Text(pr.author.login)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(pr.updatedAt, style: .relative)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isHovered ? Color.primary.opacity(0.04) : Color.clear)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
