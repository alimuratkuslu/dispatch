import AppKit
import SwiftUI

@MainActor
final class OnboardingCoordinator: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let dataStore: DataStore
    private let notificationManager: NotificationManager

    init(dataStore: DataStore, notificationManager: NotificationManager) {
        self.dataStore = dataStore
        self.notificationManager = notificationManager
    }

    func show() {
        let content = OnboardingFlow(
            dataStore: dataStore,
            notificationManager: notificationManager,
            onComplete: { [weak self] in
                self?.complete()
            }
        )

        let controller = NSHostingController(rootView: content)
        let win = NSWindow(contentViewController: controller)
        win.title = "Welcome to Dispatch"
        win.styleMask = [.titled, .closable]
        win.isReleasedWhenClosed = false
        win.delegate = self
        win.setContentSize(NSSize(width: 480, height: 540))
        win.center()
        window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func complete() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        window?.close()
        window = nil
    }

    func windowWillClose(_ notification: Notification) {
        // Allow closing without completing — user can re-open from preferences
    }
}

// MARK: - OnboardingFlow

struct OnboardingFlow: View {
    let dataStore: DataStore
    let notificationManager: NotificationManager
    let onComplete: () -> Void

    @State private var currentStep = 0

    var body: some View {
        Group {
            switch currentStep {
            case 0: WelcomeScreen(onNext: { currentStep = 1 })
            case 1: NotificationsScreen(
                notificationManager: notificationManager,
                onNext: { currentStep = 2 }
            )
            case 2: ConnectAccountScreen(
                dataStore: dataStore,
                onNext: { currentStep = 3 },
                onSkip: { currentStep = 3 }
            )
            case 3: RepoPickerScreen(
                dataStore: dataStore,
                onNext: { currentStep = 4 },
                onSkip: { currentStep = 4 }
            )
            default: DoneScreen(onDone: onComplete)
            }
        }
        .frame(width: 480, height: 540)
        .animation(.easeInOut(duration: 0.2), value: currentStep)
    }
}
