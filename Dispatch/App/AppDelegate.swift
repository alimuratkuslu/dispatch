import SwiftUI
import AppKit

@main
struct DispatchApp: App {
    // A single AppCore instance is created at startup. @State ensures it is
    // owned by SwiftUI and lives for the entire lifetime of the app.
    @State private var core = AppCore()

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
