import AppKit
import SwiftUI

@MainActor
final class StatusBarManager: NSObject, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var detailPanel: PRDetailPanel?
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
            onOpenDetail: { [weak self] pr in
                self?.openDetailPanel(for: pr)
            },
            onOpenPreferences: { [weak self] in
                self?.openPreferences()
            },
            onClosePopover: { [weak self] in
                self?.popover.performClose(nil)
            },
            onRefresh: { [weak self] in
                self?.pollingEngine.triggerImmediatePoll()
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
        let currentPR = dataStore.pullRequests.first(where: { $0.id == pr.id }) ?? pr

        // Close existing panel if showing a different PR
        if let existing = detailPanel, existing.isVisible {
            let existingTitle = existing.title
            let newTitle = "#\(currentPR.number) \(currentPR.title)"
            if existingTitle == newTitle {
                // Same PR — bring to front
                existing.makeKeyAndOrderFront(nil)
                return
            }
            existing.orderOut(nil)
        }

        guard let button = statusItem.button else { return }
        let buttonFrame = button.window?.convertToScreen(button.frame) ?? .zero
        let screen = button.window?.screen

        if detailPanel == nil {
            detailPanel = PRDetailPanel()
            detailPanel?.delegate = self
        }

        detailPanel?.show(pr: currentPR, dataStore: dataStore, onRefresh: { [weak self] in
            self?.pollingEngine.triggerImmediatePoll()
        }, near: buttonFrame, in: screen)

        // Switch popover to applicationDefined so it stays open while panel is visible
        buildPopoverIfNeeded()
        popover.behavior = .applicationDefined
        if !popover.isShown, let button = statusItem.button {
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

    private var preferencesWindow: PreferencesWindow?

    func openPreferences() {
        popover?.performClose(nil)
        if preferencesWindow == nil {
            preferencesWindow = PreferencesWindow(
                dataStore: dataStore,
                pollingEngine: pollingEngine,
                notificationManager: notificationManager
            )
        }
        preferencesWindow?.show()
        NSApp.activate(ignoringOtherApps: true)
    }

    deinit {
        observationTask?.cancel()
    }
}
