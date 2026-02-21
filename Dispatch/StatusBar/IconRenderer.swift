import AppKit
import Foundation

final class IconRenderer {
    private var cachedState: OverallState?
    private var cachedImage: NSImage?

    func image(for state: OverallState) -> NSImage {
        if let cached = cachedImage, let cs = cachedState, cs == state { return cached }
        let result = buildImage(for: state)
        cachedState = state
        cachedImage = result
        return result
    }

    private func buildImage(for state: OverallState) -> NSImage {
        // "point.3.connected.trianglepath.dotted" resembles a git commit graph —
        // immediately recognisable to developers as a VCS / PR tool.
        let symbolName = "point.3.connected.trianglepath.dotted"
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let base = (NSImage(systemSymbolName: symbolName, accessibilityDescription: "Dispatch")
                    ?? NSImage(systemSymbolName: "tray.2", accessibilityDescription: "Dispatch")!)
            .withSymbolConfiguration(config)!

        guard let dotColor = dotColor(for: state) else {
            let img = base.copy() as! NSImage
            img.isTemplate = true
            return img
        }

        // Composite the status dot onto the icon
        let size = NSSize(width: 20, height: 18)
        let result = NSImage(size: size, flipped: false) { _ in
            let iconRect = NSRect(x: 0, y: 2, width: 14, height: 14)
            base.draw(in: iconRect)

            dotColor.setFill()
            let dotRect = NSRect(x: 14, y: 0, width: 6, height: 6)
            NSBezierPath(ovalIn: dotRect).fill()
            return true
        }
        result.isTemplate = false
        return result
    }

    private func dotColor(for state: OverallState) -> NSColor? {
        switch state {
        case .error:   return .systemRed
        case .warning: return .systemOrange
        case .ok:      return .systemGreen
        case .offline: return .systemGray
        case .none:    return nil
        }
    }
}

extension OverallState: Equatable {}
