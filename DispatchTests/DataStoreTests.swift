import XCTest
@testable import DispatchApp

@MainActor
final class DataStoreTests: XCTestCase {

    private func makePR(id: String = "pr1", number: Int = 1, authorLogin: String = "alice",
                        reviews: [PRReview] = [], comments: [PRComment] = [],
                        threads: [ReviewThread] = [], requestedReviewers: [String] = [],
                        ciStatus: CIStatus = .passing) -> PullRequest {
        PullRequest(
            id: id,
            number: number,
            title: "Test PR \(number)",
            url: URL(string: "https://github.com/org/repo/pull/\(number)")!,
            author: PRAuthor(login: authorLogin, avatarURL: URL(string: "https://avatars.githubusercontent.com/u/1")!, isBot: false),
            repoFullName: "org/repo",
            isDraft: false,
            createdAt: Date(timeIntervalSinceNow: -3600),
            updatedAt: Date(timeIntervalSinceNow: -60),
            reviews: reviews,
            comments: comments,
            reviewThreads: threads,
            ciStatus: ciStatus,
            requestedReviewerLogins: requestedReviewers
        )
    }

    private func makeComment(id: String = "c1", body: String = "LGTM",
                             authorLogin: String = "bob",
                             createdAt: Date = Date()) -> PRComment {
        PRComment(
            id: id,
            body: body,
            author: PRAuthor(login: authorLogin, avatarURL: URL(string: "https://example.com/avatar.png")!, isBot: false),
            createdAt: createdAt,
            updatedAt: createdAt,
            prNodeID: "pr1"
        )
    }

    // MARK: - computeDiff

    func testNewReviewRequestAddedToNewReviewRequests() {
        let store = DataStore(storeManager: StoreManager())
        store.viewerLogin = "charlie"

        let oldPR = makePR(id: "pr1", requestedReviewers: [])
        let newPR = makePR(id: "pr1", requestedReviewers: ["charlie"])

        let diff = store.merge(newPRs: [newPR], newCIRuns: [], viewerLogin: "charlie")
        XCTAssertEqual(diff.newReviewRequests.count, 1)
        XCTAssertEqual(diff.newReviewRequests.first?.id, "pr1")
    }

    func testRemovedPRAppearsInMergedPRs() {
        let store = DataStore(storeManager: StoreManager())
        store.viewerLogin = "alice"

        let pr = makePR(id: "pr1", authorLogin: "alice")
        // Seed initial state
        store.merge(newPRs: [pr], newCIRuns: [], viewerLogin: "alice")

        // PR disappears (was merged)
        let diff = store.merge(newPRs: [], newCIRuns: [], viewerLogin: "alice")
        XCTAssertEqual(diff.mergedPRs.count, 1)
    }

    func testNewCommentAppearsInDiff() {
        let store = DataStore(storeManager: StoreManager())
        store.viewerLogin = "alice"

        let pr = makePR(id: "pr1", authorLogin: "alice")
        store.merge(newPRs: [pr], newCIRuns: [], viewerLogin: "alice")

        let comment = makeComment(id: "c1", authorLogin: "bob")
        let updatedPR = makePR(id: "pr1", authorLogin: "alice", comments: [comment])
        let diff = store.merge(newPRs: [updatedPR], newCIRuns: [], viewerLogin: "alice")

        XCTAssertEqual(diff.newComments.count, 1)
        XCTAssertEqual(diff.newComments.first?.comment.id, "c1")
    }

    func testViewerOwnCommentNotInDiff() {
        let store = DataStore(storeManager: StoreManager())
        store.viewerLogin = "alice"

        let pr = makePR(id: "pr1", authorLogin: "alice")
        store.merge(newPRs: [pr], newCIRuns: [], viewerLogin: "alice")

        // alice comments on her own PR — should not trigger notification
        let comment = makeComment(id: "c1", authorLogin: "alice")
        let updatedPR = makePR(id: "pr1", authorLogin: "alice", comments: [comment])
        let diff = store.merge(newPRs: [updatedPR], newCIRuns: [], viewerLogin: "alice")

        XCTAssertEqual(diff.newComments.count, 0)
    }

    func testCopilotReviewAppearsInDiff() {
        let store = DataStore(storeManager: StoreManager())
        store.viewerLogin = "alice"

        let pr = makePR(id: "pr1", authorLogin: "alice")
        store.merge(newPRs: [pr], newCIRuns: [], viewerLogin: "alice")

        let copilotAuthor = PRAuthor(login: "github-copilot[bot]", avatarURL: URL(string: "https://example.com")!, isBot: true)
        let review = PRReview(id: "r1", state: .commented, body: "Looks good overall.", author: copilotAuthor, submittedAt: Date(), prNodeID: "pr1")
        let updatedPR = makePR(id: "pr1", authorLogin: "alice", reviews: [review])
        let diff = store.merge(newPRs: [updatedPR], newCIRuns: [], viewerLogin: "alice")

        XCTAssertEqual(diff.newCopilotReviews.count, 1)
    }

    // MARK: - unreadCommentCount

    func testUnreadCommentCountIsCorrect() {
        let store = DataStore(storeManager: StoreManager())
        store.viewerLogin = "alice"
        store.lastSeenCommentAt = [:]  // Clear any persisted data from prior sessions

        let now = Date()
        let comment1 = makeComment(id: "c1", authorLogin: "bob", createdAt: now.addingTimeInterval(-10))
        let comment2 = makeComment(id: "c2", authorLogin: "bob", createdAt: now.addingTimeInterval(-5))
        let pr = makePR(id: "pr1", comments: [comment1, comment2])

        store.pullRequests = [pr]
        // lastSeenCommentAt not set → all comments are unread
        XCTAssertEqual(store.unreadCommentCount(for: pr), 2)
    }

    func testMarkAsReadClearsUnreadCount() {
        let store = DataStore(storeManager: StoreManager())
        store.viewerLogin = "alice"

        let comment = makeComment(id: "c1", authorLogin: "bob", createdAt: Date(timeIntervalSinceNow: -10))
        let pr = makePR(id: "pr1", comments: [comment])
        store.pullRequests = [pr]

        store.markAsRead(pr)
        XCTAssertEqual(store.unreadCommentCount(for: pr), 0)
    }
}
