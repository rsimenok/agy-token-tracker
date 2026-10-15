import SwiftUI

public struct StatusItemLabel: View {
    @ObservedObject var tracker: TrackerViewModel

    public init(tracker: TrackerViewModel) {
        self.tracker = tracker
    }

    public var body: some View {
        HStack(spacing: 5) {
            Image(systemName: tracker.isPulsing ? "bolt.circle.fill" : "bolt.fill")
                .foregroundColor(tracker.isPulsing ? .green : .primary)
                .symbolEffect(.bounce, value: tracker.isPulsing)

            if tracker.displayMode != .compact {
                Text(tracker.menuBarTitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
            }
        }
    }
}
