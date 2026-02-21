import Foundation

struct PullRequest: Codable, Identifiable, Hashable {
    let id: String              // GitHub node ID
    let number: Int
    let title: String
    let url: URL
    let author: PRAuthor
    let repoFullName: String    // injected after decoding
    let isDraft: Bool
    let headRefName: String              // source branch name
    let latestCommitMessage: String?     // head commit message (first line)
    let createdAt: Date
    let updatedAt: Date
    var reviews: [PRReview]
    var comments: [PRComment]
    var reviewThreads: [ReviewThread]
    var ciStatus: CIStatus
    var requestedReviewerLogins: [String]

    // MARK: - Computed properties

    /// Latest non-dismissed review state from any non-Copilot reviewer
    var overallReviewState: ReviewState? {
        reviews
            .filter { !$0.author.isCopilot && $0.state != .dismissed }
            .sorted(by: { $0.submittedAt < $1.submittedAt })
            .last?.state
    }

    var hasCopilotReview: Bool {
        reviews.contains(where: { $0.author.isCopilot })
    }

    var copilotReview: PRReview? {
        reviews.last(where: { $0.author.isCopilot })
    }

    var allCommentCount: Int {
        comments.count + reviewThreads.flatMap(\.comments).count
    }

    static func == (lhs: PullRequest, rhs: PullRequest) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
