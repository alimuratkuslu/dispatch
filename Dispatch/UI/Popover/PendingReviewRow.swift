import SwiftUI

struct PendingReviewRow: View {
    let pr: PullRequest
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                AvatarView(url: pr.author.avatarURL, size: 24)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(pr.repoFullName)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                        Text(pr.title)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                    }
                    HStack(spacing: 4) {
                        Text(pr.author.login)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(pr.updatedAt, style: .relative)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
