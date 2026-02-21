import SwiftUI

struct CIRowView: View {
    let ci: CIRun
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Circle()
                    .fill(ci.status.dotColor)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 1) {
                    Text(ci.repoFullName)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.branch")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        Text(ci.branch)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Text(ci.status.displayName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(ci.status.dotColor)
                    Text(ci.updatedAt, style: .relative)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
