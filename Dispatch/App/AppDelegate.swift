import SwiftUI
import AppKit

@main
struct DispatchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var core: AppCore?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize AppCore only after the app has finished launching.
        // This ensures NSStatusBar system is ready, preventing missing menu bar items on macOS Sequoia.
        core = AppCore()
    }
}
