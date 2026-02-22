import Foundation
import Network

final class PollingEngine {
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.dispatch.polling", qos: .utility)
    private var isNetworkAvailable = true
    private var networkMonitor: NWPathMonitor?

    private actor PollingState {
        var isPollInFlight = false
        var rateLimitResetDate: Date? = nil
        var backoffMultiplier: Double = 1.0
        
        func tryBeginPoll() -> Bool {
            if let reset = rateLimitResetDate, Date() < reset { return false }
            if isPollInFlight { return false }
            isPollInFlight = true
            return true
        }
        func endPoll() { isPollInFlight = false }
        func setRateLimit(_ date: Date) { rateLimitResetDate = date }
        
        func getBackoff() -> Double { return backoffMultiplier }
        func resetBackoff() -> Bool {
            if backoffMultiplier > 1 {
                backoffMultiplier = 1.0
                return true
            }
            return false
        }
        func increaseBackoff() -> Bool {
            let newMultiplier = min(backoffMultiplier * 2, 8.0)
            if newMultiplier != backoffMultiplier {
                backoffMultiplier = newMultiplier
                return true
            }
            return false
        }
    }
    private let state = PollingState()

    var pollInterval: TimeInterval {
        didSet { rescheduleTimer() }
    }

    private let apiClient: GitHubAPIClient
    private let dataStore: DataStore
    private let notificationManager: NotificationManager
    private let persistence: UserDefaultsStore

    init(apiClient: GitHubAPIClient, dataStore: DataStore, notificationManager: NotificationManager) {
        self.apiClient = apiClient
        self.dataStore = dataStore
        self.notificationManager = notificationManager
        let persistence = UserDefaultsStore()
        self.persistence = persistence
        self.pollInterval = persistence.pollInterval
    }

    // MARK: - Lifecycle
    func start() {
        scheduleTimer()
        startNetworkMonitor()
        observeLowPowerMode()
    }

    func stop() {
        timer?.cancel()
        timer = nil
        networkMonitor?.cancel()
        networkMonitor = nil
    }

    // MARK: - Manual refresh
    func triggerImmediatePoll() {
        Task { await pollIfReady() }
    }

    // MARK: - Sleep/Wake
    @objc func handleWake() {
        Task { await pollIfReady() }
    }

    func wakeUp() async {
        await pollIfReady()
    }

    // MARK: - Low Power Mode
    @objc func handlePowerStateChange() {
        let lpm = ProcessInfo.processInfo.isLowPowerModeEnabled
        pollInterval = lpm ? 120 : persistence.pollInterval
    }

    func updatePollInterval(_ interval: TimeInterval) {
        persistence.pollInterval = interval
        pollInterval = interval
    }

    // MARK: - Private
    private func scheduleTimer() {
        timer?.cancel()
        let t = DispatchSource.makeTimerSource(queue: queue)
        Task {
            let mult = await state.getBackoff()
            t.schedule(deadline: .now(), repeating: pollInterval * mult, leeway: .seconds(5))
            t.setEventHandler { [weak self] in Task { await self?.pollIfReady() } }
            t.resume()
        }
        timer = t
    }

    private func rescheduleTimer() {
        scheduleTimer()
    }

    private func startNetworkMonitor() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            let available = path.status == .satisfied
            let wasUnavailable = !(self?.isNetworkAvailable ?? true)
            self?.isNetworkAvailable = available
            if available && wasUnavailable {
                Task { await self?.pollIfReady() }
            }
            if !available {
                Task { @MainActor in self?.dataStore.isOffline = true }
            }
        }
        monitor.start(queue: queue)
        networkMonitor = monitor
    }

    private func observeLowPowerMode() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePowerStateChange),
            name: .NSProcessInfoPowerStateDidChange,
            object: nil
        )
    }

    func pollIfReady() async {
        guard isNetworkAvailable else { return }
        guard await !dataStore.monitoredRepositories.isEmpty else { return }
        
        let canPoll = await state.tryBeginPoll()
        guard canPoll else { return }
        
        await poll()
    }

    private func poll() async {
        defer { 
            Task { await state.endPoll() }
        }

        let repos = await dataStore.monitoredRepositories.filter { !$0.isPaused }
        guard !repos.isEmpty else { return }

        await MainActor.run { dataStore.isLoading = true }
        defer { Task { @MainActor in dataStore.isLoading = false } }

        var allPRs: [PullRequest] = []
        var allCIRuns: [CIRun] = []
        var latestViewerLogin = ""

        do {
            for repo in repos {
                let (prs, viewerLogin, ci) = try await apiClient.fetchPRData(repo: repo)
                allPRs.append(contentsOf: prs)
                if !viewerLogin.isEmpty { latestViewerLogin = viewerLogin }
                if let ci = ci { allCIRuns.append(ci) }
            }

            // Merge into DataStore; get raw diff (mergedPRs includes both merged+closed)
            let rawDiff = await dataStore.merge(newPRs: allPRs, newCIRuns: allCIRuns, viewerLogin: latestViewerLogin)

            let decreased = await state.resetBackoff()
            if decreased {
                rescheduleTimer()
            }

            // Split "disappeared" PRs into truly merged vs just closed via REST check
            var verifiedMerged: [PullRequest] = []
            var verifiedClosed: [PullRequest] = []
            
            await withTaskGroup(of: (PullRequest, Bool).self) { group in
                for pr in rawDiff.mergedPRs {
                    let parts = pr.repoFullName.split(separator: "/")
                    guard parts.count == 2 else { 
                        group.addTask { return (pr, true) }
                        continue 
                    }
                    let client = self.apiClient
                    group.addTask {
                        let isMerged = (try? await client.checkIsPRMerged(
                            owner: String(parts[0]), repo: String(parts[1]), number: pr.number
                        )) ?? true
                        return (pr, isMerged)
                    }
                }
                
                for await (pr, isMerged) in group {
                    if isMerged { verifiedMerged.append(pr) } else { verifiedClosed.append(pr) }
                }
            }

            let finalDiff = DataDiff(
                newFailingCI: rawDiff.newFailingCI,
                fixedCI: rawDiff.fixedCI,
                newReviewRequests: rawDiff.newReviewRequests,
                newApprovals: rawDiff.newApprovals,
                newChangesRequested: rawDiff.newChangesRequested,
                mergedPRs: verifiedMerged,
                closedPRs: verifiedClosed,
                newlyOpenedPRs: rawDiff.newlyOpenedPRs,
                newComments: rawDiff.newComments,
                newCopilotReviews: rawDiff.newCopilotReviews
            )

            if !finalDiff.isEmpty {
                notificationManager.notify(for: finalDiff)
            }
        } catch APIError.unauthorized {
            await MainActor.run { dataStore.tokenExpired = true }
        } catch APIError.rateLimitExceeded(let reset) {
            await state.setRateLimit(reset)
        } catch APIError.networkError {
            await MainActor.run { dataStore.isOffline = true }
        } catch {
            let increased = await state.increaseBackoff()
            if increased {
                rescheduleTimer()
            }
        }
    }
}
