import AppKit
import SwiftUI

@MainActor
final class StatusBarManager: NSObject, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var observationTask: Task<Void, Never>?

    // Dependencies
    private let dataStore: DataStore
    private let pollingEngine: PollingEngine
    private let notificationManager: NotificationManager
    private let iconRenderer = IconRenderer()

    init(dataStore: DataStore, pollingEngine: PollingEngine, notificationManager: NotificationManager) {
        self.dataStore = dataStore
        self.pollingEngine = pollingEngine
        self.notificationManager = notificationManager
        super.init()
        setupStatusItem()
        setupNotificationObservers()
        startObservingState()
        // Popover is built lazily on first click to avoid init-time SwiftUI crashes
    }

    // MARK: - Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        let image = NSImage(systemSymbolName: "point.3.connected.trianglepath.dotted",
                           accessibilityDescription: "Dispatch")
                   ?? NSImage(systemSymbolName: "tray.2", accessibilityDescription: "Dispatch")
                   ?? NSImage(size: NSSize(width: 18, height: 18))
        image.isTemplate = true
        button.image = image
        button.action = #selector(togglePopover)
        button.target = self
    }

    private func buildPopoverIfNeeded() {
        guard popover == nil else { return }
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 360, height: 440)

        let popoverView = PopoverView(
            pollingEngine: pollingEngine,
            notificationManager: notificationManager,
            onClosePopover: { [weak self] in
                self?.popover.performClose(nil)
            },
            onRefresh: { [weak self] in
                self?.pollingEngine.triggerImmediatePoll()
            },
            onSizeChanged: { [weak self] size in
                guard let self = self else { return }
                self.popover.animates = true
                self.popover.contentSize = size
            }
        )
        .environment(dataStore)

        let hostingController = NSHostingController(rootView: popoverView)
        popover.contentViewController = hostingController
    }

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenPRDetail(_:)),
            name: .openPRDetail,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShowPreferences),
            name: .showPreferences,
            object: nil
        )
    }

    private func startObservingState() {
        observationTask = Task { [weak self] in
            var lastState: OverallState = .none
            while !Task.isCancelled {
                guard let self = self else { return }
                let currentState = self.dataStore.overallState
                if currentState != lastState {
                    lastState = currentState
                    self.updateIcon(for: currentState)
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000) // check every second
            }
        }
    }

    private func updateIcon(for state: OverallState) {
        guard let button = statusItem.button else { return }
        button.image = iconRenderer.image(for: state)
    }

    // MARK: - Popover

    @objc private func togglePopover() {
        buildPopoverIfNeeded()
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - Detail Panel

    func openDetailPanel(for pr: PullRequest) {
        // Find the latest version of the PR from DataStore
        let _ = dataStore.pullRequests.first(where: { $0.id == pr.id }) ?? pr

        // Since we moved to popover navigation, we no longer use a separate panel.
        // If we want to support opening the popover to a specific PR (e.g. from notification),
        // we should trigger that state in PopoverView.
        // For now, we just ensure the popover is shown.
        showPopover()
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        buildPopoverIfNeeded()
        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    // MARK: - NSWindowDelegate (detail panel close)

    func windowWillClose(_ notification: Notification) {
        popover?.behavior = .transient
    }

    // MARK: - Notification handlers

    @objc private func handleOpenPRDetail(_ notification: Notification) {
        guard let prNodeID = notification.object as? String else { return }
        if let pr = dataStore.pullRequests.first(where: { $0.id == prNodeID }) {
            openDetailPanel(for: pr)
        }
    }

    @objc private func handleShowPreferences() {
        openPreferences()
    }

    // MARK: - Preferences

    func openPreferences() {
        showPopover()
        NotificationCenter.default.post(name: .showPreferences, object: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    deinit {
        observationTask?.cancel()
    }
}
