import XCTest
@testable import DispatchApp

final class CommentThreadBuilderTests: XCTestCase {
    private let builder = CommentThreadBuilder()

    private func makeAuthor(login: String = "alice", isBot: Bool = false) -> PRAuthor {
        PRAuthor(login: login, avatarURL: URL(string: "https://example.com/avatar.png")!, isBot: isBot)
    }

    private func makeComment(id: String, body: String = "Test", createdAt: Date = Date()) -> PRComment {
        PRComment(id: id, body: body, author: makeAuthor(), createdAt: createdAt, updatedAt: createdAt, prNodeID: "pr1")
    }

    private func makeReview(id: String, body: String = "Review body",
                             authorLogin: String = "bob", isBot: Bool = false,
                             state: ReviewState = .approved,
                             submittedAt: Date = Date()) -> PRReview {
        PRReview(id: id, state: state, body: body, author: makeAuthor(login: authorLogin, isBot: isBot), submittedAt: submittedAt, prNodeID: "pr1")
    }

    private func makeThread(id: String, path: String = "src/main.swift",
                             isResolved: Bool = false,
                             commentDates: [Date] = [Date()]) -> ReviewThread {
        let comments = commentDates.enumerated().map { idx, date in
            ThreadComment(
                id: "\(id)-c\(idx)", body: "Inline comment \(idx)",
                author: makeAuthor(login: "reviewer"),
                createdAt: date, isOutdated: false, replyToID: idx > 0 ? "\(id)-c0" : nil
            )
        }
        return ReviewThread(id: id, path: path, line: 10, isResolved: isResolved, comments: comments, prNodeID: "pr1")
    }

    private func makePR(comments: [PRComment] = [], reviews: [PRReview] = [],
                        threads: [ReviewThread] = []) -> PullRequest {
        PullRequest(
            id: "pr1", number: 1, title: "Test", url: URL(string: "https://github.com/org/repo/pull/1")!,
            author: makeAuthor(), repoFullName: "org/repo", isDraft: false,
            createdAt: Date(timeIntervalSinceNow: -3600), updatedAt: Date(timeIntervalSinceNow: -60),
            reviews: reviews, comments: comments, reviewThreads: threads, ciStatus: .passing,
            requestedReviewerLogins: []
        )
    }

    // MARK: - Sorting

    func testItemsSortedChronologically() {
        let early = Date(timeIntervalSinceNow: -100)
        let mid = Date(timeIntervalSinceNow: -50)
        let late = Date(timeIntervalSinceNow: -10)

        let comment = makeComment(id: "c1", createdAt: late)
        let review = makeReview(id: "r1", submittedAt: early)
        let thread = makeThread(id: "t1", commentDates: [mid])

        let pr = makePR(comments: [comment], reviews: [review], threads: [thread])
        let items = builder.build(from: pr)

        XCTAssertEqual(items.count, 3)
        // Oldest first
        if case .reviewSummary(let r) = items[0] { XCTAssertEqual(r.id, "r1") } else { XCTFail("First should be review") }
        if case .inlineThread(let t) = items[1] { XCTAssertEqual(t.id, "t1") } else { XCTFail("Second should be thread") }
        if case .generalComment(let c) = items[2] { XCTAssertEqual(c.id, "c1") } else { XCTFail("Third should be comment") }
    }

    // MARK: - Copilot filtering

    func testCopilotReviewFilteredFromGeneralItems() {
        let copilot = PRReview(
            id: "r-copilot", state: .commented, body: "LGTM",
            author: PRAuthor(login: "github-copilot[bot]", avatarURL: URL(string: "https://example.com")!, isBot: true),
            submittedAt: Date(), prNodeID: "pr1"
        )
        let human = makeReview(id: "r-human")
        let pr = makePR(reviews: [copilot, human])
        let items = builder.build(from: pr)

        // Only human review should appear in general items
        let reviewItems = items.compactMap { if case .reviewSummary(let r) = $0 { return r } else { return nil } }
        XCTAssertFalse(reviewItems.contains(where: { $0.author.isCopilot }))
        XCTAssertEqual(reviewItems.count, 1)
        XCTAssertEqual(reviewItems.first?.id, "r-human")
    }

    func testCopilotReviewAccessibleSeparately() {
        let copilot = PRReview(
            id: "r-copilot", state: .commented, body: "LGTM",
            author: PRAuthor(login: "github-copilot[bot]", avatarURL: URL(string: "https://example.com")!, isBot: true),
            submittedAt: Date(), prNodeID: "pr1"
        )
        let pr = makePR(reviews: [copilot])
        XCTAssertNotNil(builder.copilotReview(from: pr))
        XCTAssertEqual(builder.copilotReview(from: pr)?.id, "r-copilot")
    }

    // MARK: - Resolved threads

    func testResolvedThreadsExcludedByDefault() {
        let resolved = makeThread(id: "t-resolved", isResolved: true)
        let open = makeThread(id: "t-open", isResolved: false)
        let pr = makePR(threads: [resolved, open])

        let items = builder.build(from: pr, showResolvedThreads: false)
        let threadItems = items.compactMap { if case .inlineThread(let t) = $0 { return t } else { return nil } }
        XCTAssertEqual(threadItems.count, 1)
        XCTAssertEqual(threadItems.first?.id, "t-open")
    }

    func testResolvedThreadsIncludedWhenRequested() {
        let resolved = makeThread(id: "t-resolved", isResolved: true)
        let pr = makePR(threads: [resolved])

        let items = builder.build(from: pr, showResolvedThreads: true)
        XCTAssertEqual(items.count, 1)
    }

    // MARK: - Empty body reviews excluded

    func testEmptyBodyReviewExcluded() {
        let emptyReview = makeReview(id: "r-empty", body: "   ")
        let pr = makePR(reviews: [emptyReview])
        let items = builder.build(from: pr)
        XCTAssertTrue(items.isEmpty)
    }
}
