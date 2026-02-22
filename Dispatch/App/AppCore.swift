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

// MARK: - AppCore

    private var onboardingCoordinator: OnboardingCoordinator?
    private var statusBarController: StatusBarController?
    private let observerStorage = ObserverStorage()

    init() {
        dataStore = DataStore()
        notificationManager.setup()
        
        let keychain = KeychainService()
        let apiClient = GitHubAPIClient(keychainService: keychain)
        dataStore.apiClient = apiClient
        
        pollingEngine = PollingEngine(
            apiClient: apiClient,
            dataStore: dataStore,
            notificationManager: notificationManager
        )
        
        statusBarController = StatusBarController(core: self)
        
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
            guard let id = note.object as? String else { return }
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let _ = self.dataStore.pullRequests.first(where: { $0.id == id })
                self.statusBarController?.showPopover()
            }
        }

        let prefsToken = NotificationCenter.default.addObserver(
            forName: .showPreferences, object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor [weak self] in self?.openPreferences() } }

        observerStorage.tokens = [openDetailToken, prefsToken]

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

    // MARK: - Preferences

    func openPreferences() {
        statusBarController?.showPopover()
        NotificationCenter.default.post(name: .showPreferences, object: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // Initialization completes without custom deinit
}

final class ObserverStorage: @unchecked Sendable {
    var tokens: [NSObjectProtocol] = []
    deinit {
        tokens.forEach { NotificationCenter.default.removeObserver($0) }
    }
}

// MARK: - Status Bar Controller

@MainActor
final class StatusBarController: NSObject, NSPopoverDelegate {
    private var statusBarItem: NSStatusItem
    private var popover: NSPopover
    private weak var core: AppCore?
    private var eventMonitor: Any?
    
    init(core: AppCore) {
        self.core = core
        self.popover = NSPopover()
        self.statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        
        popover.contentSize = NSSize(width: 360, height: 500)
        popover.behavior = .transient
        popover.delegate = self
        
        let root = PopoverView(
            pollingEngine: core.pollingEngine,
            notificationManager: core.notificationManager,
            onClosePopover: { [weak self] in self?.popover.performClose(nil) },
            onRefresh: { [weak core] in core?.pollingEngine.triggerImmediatePoll() },
            onSizeChanged: { [weak self] size in
                guard let self = self else { return }
                self.popover.animates = true
                self.popover.contentSize = size
            }
        ).environment(core.dataStore)
        
        let hostingController = NSHostingController(rootView: root)
        popover.contentViewController = hostingController
        
        if let button = statusBarItem.button {
            button.action = #selector(handleAction)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            updateIcon()
        }
        
        NotificationCenter.default.addObserver(forName: .dataStoreUpdated, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.updateIcon() }
        }
    }

    func showPopover() {
        if !popover.isShown, let button = statusBarItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
    
    private func updateIcon() {
        guard let button = statusBarItem.button, let core = core else { return }
        
        let state = core.dataStore.overallState
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        let baseImage = NSImage(systemSymbolName: "point.3.connected.trianglepath.dotted", accessibilityDescription: "Dispatch")?.withSymbolConfiguration(config)
        
        guard let color = dotColor(for: state) else {
            button.image = baseImage
            return
        }
        
        let canvasSize = NSSize(width: 22, height: 18)
        let icon = NSImage(size: canvasSize, flipped: false) { rect in
            baseImage?.draw(in: NSRect(x: 0, y: 0, width: 18, height: 18))
            
            let dotRect = NSRect(x: 16, y: 12, width: 6, height: 6)
            NSColor(color).set()
            NSBezierPath(ovalIn: dotRect).fill()
            return true
        }
        icon.isTemplate = false
        button.image = icon
    }
    
    private func dotColor(for state: OverallState) -> Color? {
        switch state {
        case .error:   return .red
        case .warning: return .yellow
        case .ok:      return .green
        case .offline: return .gray
        case .none:    return nil
        }
    }
    
    @objc private func handleAction(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || (event?.type == .leftMouseUp && event?.modifierFlags.contains(.control) == true) {
            showContextMenu(sender)
        } else {
            togglePopover(sender)
        }
    }
    
    private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            closePopover(sender)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
            startMonitoring()
        }
    }
    
    private func closePopover(_ sender: Any?) {
        popover.performClose(sender)
        stopMonitoring()
    }
    
    nonisolated func popoverDidClose(_ notification: Notification) {
        Task { @MainActor in
            self.stopMonitoring()
        }
    }

    private func startMonitoring() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.popover.isShown else { return }
            self.closePopover(event)
        }
    }

    private func stopMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    private func showContextMenu(_ sender: NSStatusBarButton) {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(openPrefs), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Dispatch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusBarItem.menu = menu
        statusBarItem.button?.performClick(nil)
        statusBarItem.menu = nil
    }
    
    @objc private func openPrefs() {
        core?.openPreferences()
    }
}
