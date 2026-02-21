import SwiftUI

struct ReviewSummaryRow: View {
    let review: PRReview

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Review state header
            HStack(spacing: 6) {
                Image(systemName: review.state.icon)
                    .foregroundStyle(review.state.color)
                    .font(.system(size: 11))
                Text(review.state.displayName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(review.state.color)
                Text("by \(review.author.login)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(review.submittedAt, style: .relative)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(review.state.color.opacity(0.06))

            // Review body if non-empty
            if !review.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                CommentRowView(author: review.author, commentBody: review.body, date: review.submittedAt)
            }
        }
    }
}

extension ReviewState {
    var icon: String {
        switch self {
        case .approved: return "checkmark.circle.fill"
        case .changesRequested: return "exclamationmark.circle.fill"
        case .commented: return "bubble.left.fill"
        case .dismissed: return "minus.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .approved: return .green
        case .changesRequested: return .orange
        case .commented: return .secondary
        case .dismissed: return .secondary
        }
    }
}
