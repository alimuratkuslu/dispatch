import SwiftUI
import AppKit
import Observation

/// Central coordinator — owns all services and AppKit windows.
@MainActor
@Observable
final class AppCore {
    let dataStore: DataStore
    let pollingEngine: PollingEngine
    let notificationManager = NotificationManager()

    private var detailPanel: PRDetailPanel?
    private var preferencesWindowController: PreferencesWindow?
    private var onboardingCoordinator: OnboardingCoordinator?
    nonisolated(unsafe) private var observers: [NSObjectProtocol] = []

    init() {
        dataStore = DataStore()
        notificationManager.setup()

        let keychain = KeychainService()
        let apiClient = GitHubAPIClient(keychainService: keychain)
        pollingEngine = PollingEngine(
            apiClient: apiClient,
            dataStore: dataStore,
            notificationManager: notificationManager
        )
        pollingEngine.start()
        Task { await notificationManager.requestPermission() }

        // Fetch account context if token exists
        Task { [weak self] in
            guard let self else { return }
            if let token = try? await keychain.load(account: "github") {
                if let account = try? await apiClient.fetchCurrentUser(token: token) {
                    await MainActor.run {
                        self.dataStore.connectedAccount = account
                        self.dataStore.viewerLogin = account.login
                    }
                }
            }
        }

        // Use closure-based observers to avoid @objc / NSObject requirement
        let engine = pollingEngine
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil, queue: .main
        ) { _ in Task { await engine.wakeUp() } }

        NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil, queue: .main
        ) { _ in engine.handlePowerStateChange() }

        // App-level notification handlers
        let openDetailToken = NotificationCenter.default.addObserver(
            forName: .openPRDetail, object: nil, queue: .main
        ) { [weak self] note in
            guard let self, let id = note.object as? String,
                  let pr = self.dataStore.pullRequests.first(where: { $0.id == id }) else { return }
            self.openDetailPanel(for: pr)
        }

        let prefsToken = NotificationCenter.default.addObserver(
            forName: .showPreferences, object: nil, queue: .main
        ) { [weak self] _ in self?.openPreferences() }

        observers = [openDetailToken, prefsToken]

        if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self else { return }
                let coordinator = OnboardingCoordinator(
                    dataStore: self.dataStore,
                    notificationManager: self.notificationManager
                )
                coordinator.show()
                self.onboardingCoordinator = coordinator
            }
        }
    }

    // MARK: - Detail Panel

    func openDetailPanel(for pr: PullRequest) {
        let currentPR = dataStore.pullRequests.first(where: { $0.id == pr.id }) ?? pr
        if detailPanel == nil {
            detailPanel = PRDetailPanel()
        }
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let nearFrame = NSRect(x: screenFrame.maxX - 500, y: screenFrame.maxY - 40, width: 1, height: 1)
        detailPanel?.show(pr: currentPR, dataStore: dataStore, onRefresh: { [weak self] in
            self?.pollingEngine.triggerImmediatePoll()
        }, near: nearFrame, in: NSScreen.main)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Preferences

    func openPreferences() {
        if preferencesWindowController == nil {
            preferencesWindowController = PreferencesWindow(
                dataStore: dataStore,
                pollingEngine: pollingEngine,
                notificationManager: notificationManager
            )
        }
        preferencesWindowController?.show()
        NSApp.activate(ignoringOtherApps: true)
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
}
