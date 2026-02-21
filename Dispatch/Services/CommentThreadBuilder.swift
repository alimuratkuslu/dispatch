import Foundation

/// Assembles a flat, chronologically-ordered display list from raw PullRequest data.
/// Uses reviewThreads as the authoritative source for inline comments — NOT reviews.comments
/// (those are duplicates of what's in reviewThreads).
final class CommentThreadBuilder {

    enum DisplayItem: Identifiable {
        case generalComment(PRComment)
        case reviewSummary(PRReview)        // top-level review body
        case inlineThread(ReviewThread)     // grouped inline thread

        var id: String {
            switch self {
            case .generalComment(let c): return "comment-\(c.id)"
            case .reviewSummary(let r): return "review-\(r.id)"
            case .inlineThread(let t): return "thread-\(t.id)"
            }
        }

        var timestamp: Date {
            switch self {
            case .generalComment(let c): return c.createdAt
            case .reviewSummary(let r): return r.submittedAt
            case .inlineThread(let t): return t.comments.first?.createdAt ?? .distantPast
            }
        }
    }

    func build(from pr: PullRequest, showResolvedThreads: Bool = false) -> [DisplayItem] {
        var items: [DisplayItem] = []

        // 1. General PR-level comments (issue comments on the PR thread)
        let humanGeneralComments = pr.comments.filter { !$0.body.isEmpty }
        items += humanGeneralComments.map { .generalComment($0) }

        // 2. Review summary comments (top-level review body, non-Copilot, non-empty)
        let humanReviews = pr.reviews.filter { !$0.author.isCopilot && !$0.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        items += humanReviews.map { .reviewSummary($0) }

        // 3. Review threads (inline comments) — authoritative source, skip resolved unless requested
        let threads = pr.reviewThreads.filter { thread in
            !thread.comments.isEmpty && (showResolvedThreads || !thread.isResolved)
        }
        items += threads.map { .inlineThread($0) }

        // Sort chronologically
        return items.sorted(by: { $0.timestamp < $1.timestamp })
    }

    /// Returns the Copilot review if present (shown separately from regular reviews)
    func copilotReview(from pr: PullRequest) -> PRReview? {
        pr.reviews.last(where: { $0.author.isCopilot })
    }

    /// Returns Copilot's inline threads from the review threads
    func copilotThreads(from pr: PullRequest) -> [ReviewThread] {
        pr.reviewThreads.filter { thread in
            thread.comments.first?.author.isCopilot == true
        }
    }

    /// Count unread items given a last-seen date
    func unreadCount(pr: PullRequest, lastSeenAt: Date, viewerLogin: String) -> Int {
        let commentNew = pr.comments.filter { $0.createdAt > lastSeenAt && $0.author.login != viewerLogin }.count
        let threadNew = pr.reviewThreads.flatMap(\.comments).filter { $0.createdAt > lastSeenAt && $0.author.login != viewerLogin }.count
        let reviewNew = pr.reviews.filter { $0.submittedAt > lastSeenAt && $0.author.login != viewerLogin && !$0.body.isEmpty }.count
        return commentNew + threadNew + reviewNew
    }
}
