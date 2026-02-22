import Foundation

struct PullRequest: Codable, Identifiable, Hashable {
    let id: String              // GitHub node ID
    let number: Int
    let state: PRState
    let title: String
    let url: URL
    let author: PRAuthor
    let repoFullName: String    // injected after decoding
    let isDraft: Bool
    let mergeable: MergeableState
    let headRefName: String              // source branch name
    let latestCommitMessage: String?     // head commit message (first line)
    let createdAt: Date
    let updatedAt: Date
    var reviews: [PRReview]
    var comments: [PRComment]
    var reviewThreads: [ReviewThread]
    var ciStatus: CIStatus
    var requestedReviewerLogins: [String]

    enum PRState: String, Codable {
        case open = "OPEN"
        case closed = "CLOSED"
        case merged = "MERGED"
    }

    enum MergeableState: String, Codable {
        case mergeable = "MERGEABLE"
        case conflicting = "CONFLICTING"
        case unknown = "UNKNOWN"
    }

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

    var isCopilotRequested: Bool {
        requestedReviewerLogins.contains(where: { $0.lowercased().contains("copilot") })
    }

    var copilotReview: PRReview? {
        reviews.last(where: { $0.author.isCopilot })
    }

    var allCommentCount: Int {
        comments.count + reviewThreads.flatMap(\.comments).count
    }

    var localCleanupCommand: String {
        "git checkout main && git pull && git branch -d \(headRefName)"
    }

    static func == (lhs: PullRequest, rhs: PullRequest) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
