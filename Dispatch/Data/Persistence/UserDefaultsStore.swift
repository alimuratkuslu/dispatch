import Foundation

final class UserDefaultsStore {
    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private enum Keys {
        static let monitoredRepos = "monitoredRepos"
        static let lastSeenCommentAt = "lastSeenCommentAt"
        static let connectedAccountLogin = "connectedAccountLogin"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let pollInterval = "pollInterval"
        static let notificationPrefs = "notificationPrefs"
        static let copilotReviewsEnabled = "copilotReviewsEnabled"
        static let launchOnStartup = "launchOnStartup"
    }

    init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Repos
    func save(repos: [MonitoredRepo]) {
        let data = try? encoder.encode(repos)
        defaults.set(data, forKey: Keys.monitoredRepos)
    }

    func loadRepos() -> [MonitoredRepo] {
        guard let data = defaults.data(forKey: Keys.monitoredRepos) else { return [] }
        return (try? decoder.decode([MonitoredRepo].self, from: data)) ?? []
    }

    // MARK: - Unread tracking
    func save(lastSeenCommentAt: [String: Date]) {
        // Store as [String: Double] (timeIntervalSince1970) for simplicity
        let raw = lastSeenCommentAt.mapValues { $0.timeIntervalSince1970 }
        defaults.set(raw, forKey: Keys.lastSeenCommentAt)
    }

    func loadLastSeenCommentAt() -> [String: Date] {
        guard let raw = defaults.dictionary(forKey: Keys.lastSeenCommentAt) as? [String: Double] else { return [:] }
        return raw.mapValues { Date(timeIntervalSince1970: $0) }
    }

    // MARK: - Account
    func save(accountLogin: String?) {
        defaults.set(accountLogin, forKey: Keys.connectedAccountLogin)
    }

    func loadAccountLogin() -> String? {
        defaults.string(forKey: Keys.connectedAccountLogin)
    }

    // MARK: - Onboarding
    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Keys.hasCompletedOnboarding) }
        set { defaults.set(newValue, forKey: Keys.hasCompletedOnboarding) }
    }

    // MARK: - Poll interval
    var pollInterval: TimeInterval {
        get {
            let v = defaults.double(forKey: Keys.pollInterval)
            return v > 0 ? v : 15
        }
        set { defaults.set(newValue, forKey: Keys.pollInterval) }
    }

    // MARK: - Copilot reviews
    var copilotReviewsEnabled: Bool {
        get { defaults.bool(forKey: Keys.copilotReviewsEnabled) }
        set { defaults.set(newValue, forKey: Keys.copilotReviewsEnabled) }
    }

    // MARK: - Notifications
    func save(notificationPrefs: NotificationPreferences) {
        let data = try? encoder.encode(notificationPrefs)
        defaults.set(data, forKey: Keys.notificationPrefs)
    }

    func loadNotificationPrefs() -> NotificationPreferences {
        guard let data = defaults.data(forKey: Keys.notificationPrefs) else {
            return NotificationPreferences()
        }
        return (try? decoder.decode(NotificationPreferences.self, from: data)) ?? NotificationPreferences()
    }
}
