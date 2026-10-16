import Testing
import SwiftUI
import AppKit
@testable import AGYTokenTracker

@Suite("Screenshot Generator")
struct ScreenshotGeneratorTests {
    @Test(
        "Generate app screenshots with window contour, shadow, and full-width pickers",
        .enabled(if: ProcessInfo.processInfo.environment["GENERATE_SCREENSHOTS"] != nil, "Run with GENERATE_SCREENSHOTS=1 to regenerate assets")
    )
    @MainActor
    func generateScreenshots() async throws {
        let tracker = TrackerViewModel(startBackgroundServices: false)
        
        let (steps, sessions) = UnifiedScanner.shared.scanAllSurfaces()
        tracker.allSteps = steps
        tracker.allSessions = sessions
        tracker.recomputeMetrics()
        
        let contentWidth: CGFloat = 380
        let contentHeight: CGFloat = 620
        let padding: CGFloat = 26
        
        let windowWidth = contentWidth + padding * 2
        let windowHeight = contentHeight + padding * 2
        
        let window = NSWindow(
            contentRect: NSRect(x: 200, y: 200, width: windowWidth, height: windowHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        
        defer {
            window.orderOut(nil)
            window.close()
        }
        
        struct WindowContourWrapper<Content: View>: View {
            let content: Content
            let width: CGFloat
            let height: CGFloat
            let padding: CGFloat
            
            var body: some View {
                ZStack {
                    Color.clear
                    
                    content
                        .frame(width: width, height: height)
                        .background(Color(nsColor: .windowBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color(nsColor: .separatorColor).opacity(0.8), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.30), radius: 16, x: 0, y: 8)
                }
                .frame(width: width + padding * 2, height: height + padding * 2)
            }
        }
        
        func capture(name: String) async {
            let view = WindowContourWrapper(
                content: DashboardView(tracker: tracker),
                width: contentWidth,
                height: contentHeight,
                padding: padding
            )
            window.contentView = NSHostingView(rootView: view)
            window.makeKeyAndOrderFront(nil)
            window.display()
            try? await Task.sleep(nanoseconds: 700_000_000)
            
            let winId = window.windowNumber
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = ["-l", "\(winId)", "-o", "assets/\(name).png"]
            try? process.run()
            process.waitUntilExit()
            print("Captured assets/\(name).png with full-width controls from window \(winId)")
        }
        
        // 1. Overview
        tracker.currentView = .overview
        tracker.isShowingSettings = false
        await capture(name: "dashboard")
        
        // 2. Models
        tracker.currentView = .models
        tracker.isShowingSettings = false
        await capture(name: "models")
        
        // 3. Sessions
        tracker.currentView = .sessions
        tracker.isShowingSettings = false
        await capture(name: "sessions")
        
        // 4. Settings
        tracker.isShowingSettings = true
        await capture(name: "settings")
    }
}
