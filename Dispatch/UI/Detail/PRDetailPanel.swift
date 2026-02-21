import AppKit
import SwiftUI

final class PRDetailPanel: NSPanel {
    private var hostingController: NSHostingController<AnyView>?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 580),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isReleasedWhenClosed = false  // CRITICAL: prevents deallocation on user close
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
        hidesOnDeactivate = false
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        backgroundColor = NSColor.windowBackgroundColor
    }

    func show(pr: PullRequest, dataStore: DataStore, onRefresh: @escaping () -> Void = {}, near buttonFrame: NSRect, in screen: NSScreen?) {
        title = "#\(pr.number) \(pr.title)"

        var detailView = PRDetailView(pr: pr)
        detailView.onRefresh = onRefresh
        let view = detailView.environment(dataStore)

        let hosting = NSHostingController(rootView: AnyView(view))
        hosting.view.frame = NSRect(x: 0, y: 0, width: 480, height: 580)
        contentViewController = hosting
        hostingController = hosting

        setContentSize(NSSize(width: 480, height: 580))
        positionNear(buttonFrame: buttonFrame, screen: screen)
        makeKeyAndOrderFront(nil)
    }

    override func close() {
        orderOut(nil)
    }

    private func positionNear(buttonFrame: NSRect, screen: NSScreen?) {
        guard let screen = screen ?? NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let windowSize = NSSize(width: 480, height: 580)

        // Try to place to the right of the popover area
        var origin = NSPoint(
            x: buttonFrame.minX + 370,  // popover width (360) + gap (10)
            y: screenFrame.maxY - windowSize.height - 40
        )

        // If off-screen to the right, place to the left
        if origin.x + windowSize.width > screenFrame.maxX {
            origin.x = buttonFrame.minX - windowSize.width - 10
        }

        // Clamp vertically
        origin.y = max(screenFrame.minY, min(origin.y, screenFrame.maxY - windowSize.height))

        setFrameOrigin(origin)
    }
}
