import SwiftUI
import AppKit

public struct FocusRingCleaner: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: Context) -> NSView {
        FocusRingCleanerView()
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        FocusRingCleanerHelper.cleanFocusRings(in: nsView.window)
    }
}

private final class FocusRingCleanerView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        clean()
    }

    override func layout() {
        super.layout()
        clean()
    }

    private func clean() {
        DispatchQueue.main.async { [weak self] in
            guard let window = self?.window else { return }
            FocusRingCleanerHelper.cleanFocusRings(in: window)
        }
    }
}

@MainActor
public enum FocusRingCleanerHelper {
    public static func cleanFocusRings(in window: NSWindow?) {
        guard let window = window else { return }
        window.makeFirstResponder(nil)
        cleanViews(in: window.contentView)
    }

    private static func cleanViews(in view: NSView?) {
        guard let view = view else { return }
        if let control = view as? NSControl {
            control.focusRingType = .none
            control.refusesFirstResponder = true
        }
        for subview in view.subviews {
            cleanViews(in: subview)
        }
    }
}
