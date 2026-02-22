import Foundation
import Network

final class PollingEngine {
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.dispatch.polling", qos: .utility)
    private var backoffMultiplier: Double = 1.0
    private var isNetworkAvailable = true
    private var rateLimitResetDate: Date? = nil
    private var networkMonitor: NWPathMonitor?
    private var isPollInFlight = false
    private let stateLock = NSLock()

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
        self.persistence = dataStore.persistence
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
        t.schedule(deadline: .now(), repeating: pollInterval * backoffMultiplier, leeway: .seconds(5))
        t.setEventHandler { [weak self] in Task { await self?.pollIfReady() } }
        t.resume()
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
        
        stateLock.lock()
        if let reset = rateLimitResetDate, Date() < reset {
            stateLock.unlock()
            return 
        }
        guard !isPollInFlight else { 
            stateLock.unlock()
            return 
        }
        isPollInFlight = true
        stateLock.unlock()
        
        await poll()
    }

    private func poll() async {
        defer { 
            stateLock.lock()
            isPollInFlight = false 
            stateLock.unlock()
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

            stateLock.lock()
            let currentMultiplier = backoffMultiplier
            if currentMultiplier > 1 {
                backoffMultiplier = 1.0
                stateLock.unlock()
                rescheduleTimer()
            } else {
                stateLock.unlock()
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
            stateLock.lock()
            rateLimitResetDate = reset
            stateLock.unlock()
        } catch APIError.networkError {
            await MainActor.run { dataStore.isOffline = true }
        } catch {
            stateLock.lock()
            let newMultiplier = min(backoffMultiplier * 2, 8.0)
            let changed = (newMultiplier != backoffMultiplier)
            if changed {
                backoffMultiplier = newMultiplier
            }
            stateLock.unlock()
            
            if changed {
                rescheduleTimer()
            }
        }
    }
}
