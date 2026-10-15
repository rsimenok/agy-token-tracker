import SwiftUI

public struct SessionRowView: View {
    let session: SessionSummary

    public init(session: SessionSummary) {
        self.session = session
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.accentColor)

                    Text(shortSessionId(session.id))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)
                }

                if let model = session.modelName {
                    Text(model)
                        .font(.system(size: 9, weight: .medium))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Color.blue.opacity(0.12))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }

                Spacer()

                Text(TrackerViewModel.formatCurrency(session.estimatedCost))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.green)
            }

            HStack {
                Text("\(session.stepCount) steps")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Text("•")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary.opacity(0.5))

                Text("\(TrackerViewModel.formatCompact(session.totalTokens)) tokens")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)

                if session.cacheReadTokens > 0 {
                    Text("(\(Int(session.cacheHitRatio * 100))% cached)")
                        .font(.system(size: 9))
                        .foregroundColor(.purple)
                }

                Spacer()

                Text(relativeDateString(for: session.lastUpdated))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.35))
        )
    }

    private func shortSessionId(_ id: String) -> String {
        if id.count > 16 {
            let prefix = id.prefix(8)
            let suffix = id.suffix(4)
            return "\(prefix)...\(suffix)"
        }
        return id
    }

    private func relativeDateString(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
