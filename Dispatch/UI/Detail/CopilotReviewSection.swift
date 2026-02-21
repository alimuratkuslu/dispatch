import SwiftUI

struct CopilotReviewSection: View {
    let review: PRReview
    let inlineThreadCount: Int
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Copilot banner header
            HStack(spacing: 8) {
                Label("Copilot", systemImage: "cpu.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.purple)

                Capsule()
                    .fill(review.state.color.opacity(0.15))
                    .frame(height: 16)
                    .overlay {
                        Text(review.state.displayName)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(review.state.color)
                    }

                Spacer()

                Text(review.submittedAt, style: .relative)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)

                Button(action: { withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.purple.opacity(0.06))

            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    if !review.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(review.body)
                            .font(.system(size: 11))
                            .lineLimit(4)
                            .padding(.horizontal, 12)
                            .padding(.top, 6)
                    }

                    if inlineThreadCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            Text("\(inlineThreadCount) inline comment\(inlineThreadCount == 1 ? "" : "s") — scroll down to see them")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                    }
                }
            }
        }
        .background(.purple.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.purple.opacity(0.2), lineWidth: 1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }
}
