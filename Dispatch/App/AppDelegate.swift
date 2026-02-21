import SwiftUI
import AppKit

@main
struct DispatchApp: App {
    @State private var core = AppCore()

    var body: some Scene {
        MenuBarExtra {
            PopoverView(
                onOpenDetail: { pr in core.openDetailPanel(for: pr) },
                onOpenPreferences: { core.openPreferences() },
                onClosePopover: { },   // MenuBarExtra dismisses itself on outside click
                onRefresh: { core.pollingEngine.triggerImmediatePoll() }
            )
            .environment(core.dataStore)
        } label: {
            MenuBarLabel(state: core.dataStore.overallState)
        }
        .menuBarExtraStyle(.window)
    }
}

/// The menu bar icon — changes color dot based on overall state.
struct MenuBarLabel: View {
    let state: OverallState

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 13, weight: .medium))
            if let color = dotColor {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                    .offset(y: -3)
            }
        }
    }

    private var dotColor: Color? {
        switch state {
        case .error:   return .red
        case .warning: return .yellow
        case .ok:      return .green
        case .offline: return .gray
        case .none:    return nil
        }
    }
}
