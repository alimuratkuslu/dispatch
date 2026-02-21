import Foundation
import UserNotifications
import AppKit

struct NotificationPreferences: Codable {
    var masterEnabled: Bool = true
    var newPREnabled: Bool = true
    var ciFailEnabled: Bool = true
    var ciFixEnabled: Bool = true
    var reviewRequestEnabled: Bool = true
    var approvalEnabled: Bool = true
    var changesRequestedEnabled: Bool = true
    var mergeEnabled: Bool = true
    var closedEnabled: Bool = true
    var commentEnabled: Bool = true
    var copilotEnabled: Bool = true
}

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    private var sentIDs: Set<String> = []
    private(set) var permissionGranted: Bool = false
    var preferences: NotificationPreferences = NotificationPreferences()

    override init() {
        super.init()
    }

    func setup() {
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            permissionGranted = granted
        } catch {
            permissionGranted = false
        }
    }

    func checkPermission() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            permissionGranted = settings.authorizationStatus == .authorized
        }
    }

    // MARK: - Notify from diff
    func notify(for diff: DataDiff) {
        guard preferences.masterEnabled else { return }
        if preferences.newPREnabled         { diff.newlyOpenedPRs.forEach { fire_N0($0) } }
        if preferences.ciFailEnabled        { diff.newFailingCI.forEach { fire_N1($0) } }
        if preferences.ciFixEnabled         { diff.fixedCI.forEach { fire_N2($0) } }
        if preferences.reviewRequestEnabled { diff.newReviewRequests.forEach { fire_N3($0) } }
        if preferences.approvalEnabled      { diff.newApprovals.forEach { fire_N4($0) } }
        if preferences.changesRequestedEnabled { diff.newChangesRequested.forEach { fire_N5($0) } }
        if preferences.mergeEnabled         { diff.mergedPRs.forEach { fire_N6($0) } }
        if preferences.closedEnabled        { diff.closedPRs.forEach { fire_N6_closed($0) } }
        if preferences.commentEnabled       { diff.newComments.forEach { fire_N7($0) } }
        if preferences.copilotEnabled       { diff.newCopilotReviews.forEach { fire_N8($0) } }
    }

    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Dispatch"
        content.body = "Test notification from Dispatch."
        content.sound = .default
        let req = UNNotificationRequest(identifier: "dispatch.test.\(Date().timeIntervalSince1970)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }

    // MARK: - Event fires

    private func fire(identifier: String, title: String, body: String, userInfo: [AnyHashable: Any] = [:]) {
        guard !sentIDs.contains(identifier) else { return }
        // Reserve the slot optimistically so concurrent polls don't double-fire,
        // but remove it in the completion handler if the OS rejects it so the
        // next poll can retry (e.g. permission was just granted).
        sentIDs.insert(identifier)
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = userInfo
        let req = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req) { [weak self] error in
            if error != nil {
                // OS rejected it (permission not granted, etc.) — allow retry next poll
                DispatchQueue.main.async { self?.sentIDs.remove(identifier) }
            }
        }
    }

    // N0 — New PR opened
    private func fire_N0(_ pr: PullRequest) {
        var body = "\(pr.author.login) → \(pr.headRefName)\n\(pr.title)"
        if let msg = pr.latestCommitMessage, !msg.isEmpty {
            body += "\n\"\(String(msg.prefix(80)))\""
        }
        fire(identifier: "N0-\(pr.repoFullName)-\(pr.number)",
             title: "🔍 New PR — \(pr.repoFullName)",
             body: body,
             userInfo: ["eventType": "N0", "prNodeID": pr.id])
    }

    // N1 — CI failed
    private func fire_N1(_ ci: CIRun) {
        fire(identifier: "N1-\(ci.repoFullName)",
             title: "❌ CI Failed — \(ci.repoFullName)",
             body: "\(ci.branch) build is failing",
             userInfo: ["eventType": "N1", "url": ci.url?.absoluteString ?? ""])
    }

    // N2 — CI fixed
    private func fire_N2(_ ci: CIRun) {
        fire(identifier: "N2-\(ci.repoFullName)-\(Date().timeIntervalSince1970)",
             title: "✅ CI Fixed — \(ci.repoFullName)",
             body: "\(ci.branch) builds are passing again",
             userInfo: ["eventType": "N2", "url": ci.url?.absoluteString ?? ""])
    }

    // N3 — Review requested
    private func fire_N3(_ pr: PullRequest) {
        fire(identifier: "N3-\(pr.repoFullName)-\(pr.number)",
             title: "👀 Review Requested",
             body: "\(pr.author.login) wants your review: \(pr.title)",
             userInfo: ["eventType": "N3", "prNodeID": pr.id])
    }

    // N4 — PR approved
    private func fire_N4(_ pr: PullRequest) {
        fire(identifier: "N4-\(pr.repoFullName)-\(pr.number)-\(Date().timeIntervalSince1970)",
             title: "✅ PR Approved",
             body: "Your PR was approved: \(pr.title)",
             userInfo: ["eventType": "N4", "prNodeID": pr.id])
    }

    // N5 — Changes requested
    private func fire_N5(_ pr: PullRequest) {
        fire(identifier: "N5-\(pr.repoFullName)-\(pr.number)-\(Date().timeIntervalSince1970)",
             title: "🔄 Changes Requested",
             body: "Changes requested on: \(pr.title)",
             userInfo: ["eventType": "N5", "prNodeID": pr.id])
    }

    // N6 — PR merged (purple = celebration)
    private func fire_N6(_ pr: PullRequest) {
        fire(identifier: "N6-\(pr.repoFullName)-\(pr.number)",
             title: "🟣 PR Merged — \(pr.repoFullName)",
             body: "[\(pr.headRefName)] \(pr.title)",
             userInfo: ["eventType": "N6", "prNodeID": pr.id])
    }

    // N6_closed — PR closed without merge (grey = neutral/cancelled)
    private func fire_N6_closed(_ pr: PullRequest) {
        fire(identifier: "N6c-\(pr.repoFullName)-\(pr.number)",
             title: "🔴 PR Closed — \(pr.repoFullName)",
             body: "[\(pr.headRefName)] \(pr.title)",
             userInfo: ["eventType": "N6c", "prNodeID": pr.id])
    }

    // N7 — New comment
    private func fire_N7(_ payload: CommentNotificationPayload) {
        let preview = String(payload.body.prefix(80))
        fire(identifier: "N7-\(payload.pr.repoFullName)-\(payload.pr.number)-\(payload.id)",
             title: "💬 New Comment",
             body: "\(payload.author.login) on \(payload.pr.title): \"\(preview)\"",
             userInfo: ["eventType": "N7", "prNodeID": payload.pr.id])
    }

    // N8 — Copilot review
    private func fire_N8(_ pr: PullRequest) {
        let summary = String((pr.copilotReview?.body ?? "Copilot has reviewed your PR.").prefix(80))
        fire(identifier: "N8-\(pr.repoFullName)-\(pr.number)",
             title: "🤖 Copilot Review Ready",
             body: summary,
             userInfo: ["eventType": "N8", "prNodeID": pr.id])
    }

    // MARK: - UNUserNotificationCenterDelegate
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 willPresent notification: UNNotification,
                                 withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 didReceive response: UNNotificationResponse,
                                 withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        if let prNodeID = userInfo["prNodeID"] as? String {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .openPRDetail, object: prNodeID)
            }
        } else if let urlStr = userInfo["url"] as? String, let url = URL(string: urlStr), !urlStr.isEmpty {
            NSWorkspace.shared.open(url)
        }
        completionHandler()
    }
}
