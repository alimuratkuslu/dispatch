import Foundation

struct CommentNotificationPayload {
    let pr: PullRequest
    let id: String
    let body: String
    let author: PRAuthor
}

struct DataDiff {
    let newFailingCI: [CIRun]
    let fixedCI: [CIRun]
    let newReviewRequests: [PullRequest]
    let newApprovals: [PullRequest]
    let newChangesRequested: [PullRequest]
    let mergedPRs: [PullRequest]
    let closedPRs: [PullRequest]             // PR closed without merge
    let newlyOpenedPRs: [PullRequest]        // PR just opened by someone
    let newComments: [CommentNotificationPayload]
    let newCopilotReviews: [PullRequest]

    var isEmpty: Bool {
        newFailingCI.isEmpty && fixedCI.isEmpty && newReviewRequests.isEmpty &&
        newApprovals.isEmpty && newChangesRequested.isEmpty && mergedPRs.isEmpty &&
        closedPRs.isEmpty && newlyOpenedPRs.isEmpty &&
        newComments.isEmpty && newCopilotReviews.isEmpty
    }

    static let empty = DataDiff(
        newFailingCI: [], fixedCI: [], newReviewRequests: [],
        newApprovals: [], newChangesRequested: [], mergedPRs: [],
        closedPRs: [], newlyOpenedPRs: [],
        newComments: [], newCopilotReviews: []
    )
}
