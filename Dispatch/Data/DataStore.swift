import Foundation
import Observation

@MainActor
@Observable
final class DataStore {
    // MARK: - Published state
    var monitoredRepositories: [MonitoredRepo] = []
    var pullRequests: [PullRequest] = []
    var ciRuns: [CIRun] = []
    var reviewRequests: [PullRequest] = []          // subset: viewer is requested reviewer
    var connectedAccount: Account? = nil
    var viewerLogin: String = ""
    var isLoading: Bool = false
    var isOffline: Bool = false
    var tokenExpired: Bool = false
    var lastPollDate: Date? = nil
    var lastSeenCommentAt: [String: Date] = [:]     // [prNodeID: Date]

    var hideDrafts: Bool {
        get { persistence.hideDrafts }
        set { persistence.hideDrafts = newValue }
    }

    var sortByActivity: Bool {
        get { persistence.sortByActivity }
        set { persistence.sortByActivity = newValue }
    }

    var visiblePullRequests: [PullRequest] {
        let filtered = hideDrafts ? pullRequests.filter { !$0.isDraft } : pullRequests
        if sortByActivity {
            return filtered.sorted { $0.updatedAt > $1.updatedAt }
        } else {
            return filtered.sorted { $0.createdAt > $1.createdAt }
        }
    }

    // MARK: - Dependencies
    let persistence: UserDefaultsStore
    var apiClient: GitHubAPIClient!
    /// Records when this DataStore instance was created — used to determine
    /// whether a newly-seen PR was opened *before* or *after* the app launched.
    let startupDate: Date = Date()

    init() {
        self.persistence = UserDefaultsStore()
        loadPersistedData()
    }

    // MARK: - Overall state (drives menu bar icon dot)
    var overallState: OverallState {
        guard !isOffline else { return .offline }
        guard !monitoredRepositories.isEmpty else { return .none }
        if ciRuns.contains(where: { $0.status == .failing }) { return .error }
        if pullRequests.contains(where: { $0.overallReviewState == .changesRequested }) { return .error }
        if !reviewRequests.isEmpty { return .warning }
        if pullRequests.contains(where: { unreadCommentCount(for: $0) > 0 }) { return .warning }
        if !pullRequests.isEmpty { return .ok }
        return .none
    }

    // MARK: - Unread tracking
    func unreadCommentCount(for pr: PullRequest) -> Int {
        let lastSeen = lastSeenCommentAt[pr.id] ?? .distantPast
        let generalNew = pr.comments.filter { $0.createdAt > lastSeen && $0.author.login != viewerLogin }.count
        let threadNew = pr.reviewThreads.flatMap(\.comments).filter { $0.createdAt > lastSeen && $0.author.login != viewerLogin }.count
        let reviewNew = pr.reviews.filter { $0.submittedAt > lastSeen && $0.author.login != viewerLogin && !$0.body.isEmpty }.count
        return generalNew + threadNew + reviewNew
    }

    func markAsRead(_ pr: PullRequest) {
        lastSeenCommentAt[pr.id] = Date()
        persistence.save(lastSeenCommentAt: lastSeenCommentAt)
    }

    // MARK: - Repository management
    func addRepository(_ repo: MonitoredRepo) throws {
        guard !monitoredRepositories.contains(where: { $0.id == repo.id }) else { return }
        monitoredRepositories.append(repo)
        persistence.save(repos: monitoredRepositories)
    }

    func removeRepository(_ repo: MonitoredRepo) {
        monitoredRepositories.removeAll { $0.id == repo.id }
        pullRequests.removeAll { $0.repoFullName == repo.fullName }
        ciRuns.removeAll { $0.repoFullName == repo.fullName }
        reviewRequests.removeAll { $0.repoFullName == repo.fullName }
        persistence.save(repos: monitoredRepositories)
    }

    func pauseExtraRepositories() {
        for i in monitoredRepositories.indices where i > 0 {
            monitoredRepositories[i].isPaused = true
        }
        persistence.save(repos: monitoredRepositories)
    }

    func resumeAllRepositories() {
        for i in monitoredRepositories.indices {
            monitoredRepositories[i].isPaused = false
        }
        persistence.save(repos: monitoredRepositories)
    }

    // MARK: - Data merge (called by PollingEngine)
    @discardableResult
    func merge(newPRs: [PullRequest], newCIRuns: [CIRun], viewerLogin: String) -> DataDiff {
        self.viewerLogin = viewerLogin
        let diff = computeDiff(
            oldPRs: pullRequests, newPRs: newPRs,
            oldCI: ciRuns, newCI: newCIRuns,
            viewerLogin: viewerLogin
        )
        pullRequests = newPRs
        ciRuns = newCIRuns
        reviewRequests = newPRs.filter { $0.requestedReviewerLogins.contains(viewerLogin) }
        lastPollDate = Date()
        isOffline = false
        tokenExpired = false
        
        NotificationCenter.default.post(name: .dataStoreUpdated, object: nil)
        
        return diff
    }

    // MARK: - Private diff computation
    private func computeDiff(
        oldPRs: [PullRequest], newPRs: [PullRequest],
        oldCI: [CIRun], newCI: [CIRun],
        viewerLogin: String
    ) -> DataDiff {
        let oldPRMap = Dictionary(uniqueKeysWithValues: oldPRs.map { ($0.id, $0) })
        let oldCIMap = Dictionary(uniqueKeysWithValues: oldCI.map { ($0.repoFullName, $0) })
        let ignoreSelf = UserDefaults.standard.bool(forKey: "notif.ignoreSelfActions")

        // Newly opened PRs — fires when:
        //   a) The PR didn't exist in the previous snapshot AND was created after app startup, OR
        //   b) A known PR transitioned from draft → ready for review.
        // Using createdAt > startupDate means we notify on the FIRST poll if the user just opened a PR,
        // without blasting notifications for all pre-existing PRs on app launch.
        let newlyOpened: [PullRequest] = newPRs.filter { pr in
            guard !pr.isDraft else { return false }
            if ignoreSelf && pr.author.login == viewerLogin { return false }
            if let old = oldPRMap[pr.id] {
                // Known PR: only notify if it just transitioned from draft → ready
                return old.isDraft
            }
            // New PR (not seen before): only notify if it was created after this session started
            return pr.createdAt > startupDate
        }

        // CI changes
        let newFailing = newCI.filter { $0.status == .failing && oldCIMap[$0.repoFullName]?.status != .failing }
        let fixed = newCI.filter { $0.status == .passing && oldCIMap[$0.repoFullName]?.status == .failing }

        // Review request changes — skip first-load blast & only new requests for the viewer
        let newRevReqs: [PullRequest] = oldPRs.isEmpty ? [] : newPRs.filter { pr in
            guard pr.requestedReviewerLogins.contains(viewerLogin) else { return false }
            guard !(oldPRMap[pr.id]?.requestedReviewerLogins.contains(viewerLogin) ?? false) else { return false }
            if ignoreSelf && pr.author.login == viewerLogin { return false }
            return true
        }

        // New approvals
        let newApprovals = newPRs.filter { pr in
            pr.overallReviewState == .approved &&
            oldPRMap[pr.id]?.overallReviewState != .approved
        }
        .filter { ignoreSelf ? $0.reviews.first(where: { $0.state == .approved })?.author.login != viewerLogin : true }

        // New changes-requested
        let newChanges = newPRs.filter { pr in
            pr.overallReviewState == .changesRequested &&
            oldPRMap[pr.id]?.overallReviewState != .changesRequested
        }
        .filter { ignoreSelf ? $0.reviews.first(where: { $0.state == .changesRequested })?.author.login != viewerLogin : true }

        // PRs that were open, now gone (merged or closed) — notify for all, not just viewer's
        let newPRIDs = Set(newPRs.map(\.id))
        let merged = oldPRs.filter { !newPRIDs.contains($0.id) }

        // New comments (general + thread + reviews)
        var newComments: [CommentNotificationPayload] = []
        for pr in newPRs {
            let oldPr = oldPRMap[pr.id]
            
            // 1. General comments
            let oldGeneralIDs = Set(oldPr?.comments.map(\.id) ?? [])
            let freshGeneral = pr.comments.filter {
                !oldGeneralIDs.contains($0.id) && !$0.author.isCopilot &&
                (ignoreSelf ? $0.author.login != viewerLogin : true)
            }
            for c in freshGeneral {
                newComments.append(CommentNotificationPayload(pr: pr, id: c.id, body: c.body, author: c.author))
            }
            
            // 2. Thread comments
            let oldThreadIDs = Set(oldPr?.reviewThreads.flatMap(\.comments).map(\.id) ?? [])
            let freshThread = pr.reviewThreads.flatMap(\.comments).filter {
                !oldThreadIDs.contains($0.id) && !$0.author.isCopilot &&
                (ignoreSelf ? $0.author.login != viewerLogin : true)
            }
            for c in freshThread {
                newComments.append(CommentNotificationPayload(pr: pr, id: c.id, body: c.body, author: c.author))
            }
            
            // 3. Review bodies
            let oldReviewIDs = Set(oldPr?.reviews.map(\.id) ?? [])
            let freshReviews = pr.reviews.filter {
                !oldReviewIDs.contains($0.id) && !$0.author.isCopilot && !$0.body.isEmpty &&
                (ignoreSelf ? $0.author.login != viewerLogin : true)
            }
            for r in freshReviews {
                newComments.append(CommentNotificationPayload(pr: pr, id: r.id, body: r.body, author: r.author))
            }
        }

        // New Copilot reviews
        let newCopilot = newPRs.filter { pr in
            pr.hasCopilotReview && !(oldPRMap[pr.id]?.hasCopilotReview ?? false)
        }

        return DataDiff(
            newFailingCI: newFailing, fixedCI: fixed,
            newReviewRequests: newRevReqs, newApprovals: newApprovals,
            newChangesRequested: newChanges, mergedPRs: merged,
            closedPRs: [],               // split from mergedPRs by PollingEngine after REST check
            newlyOpenedPRs: newlyOpened,
            newComments: newComments, newCopilotReviews: newCopilot
        )
    }

    // MARK: - Persistence
    private func loadPersistedData() {
        monitoredRepositories = persistence.loadRepos()
        lastSeenCommentAt = persistence.loadLastSeenCommentAt()
    }
}

enum OverallState { case error, warning, ok, offline, none }

extension Notification.Name {
    static let openPRDetail = Notification.Name("com.dispatch.openPRDetail")
    static let showPreferences = Notification.Name("com.dispatch.showPreferences")
    static let dataStoreUpdated = Notification.Name("com.dispatch.dataStoreUpdated")
}
