import SwiftUI
import AppKit

@main
struct AGYTokenTrackerApp: App {
    @StateObject private var tracker = TrackerViewModel()

    init() {
        // Run as menu bar accessory app (hides Dock icon)
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            DashboardView(tracker: tracker)
        } label: {
            StatusItemLabel(tracker: tracker)
        }
        .menuBarExtraStyle(.window)
    }
}
