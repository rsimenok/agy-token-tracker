import SwiftUI

public struct ModelUsageRowView: View {
    let model: ModelUsage
    let isSelected: Bool
    let onSelect: () -> Void

    public init(model: ModelUsage, isSelected: Bool = false, onSelect: @escaping () -> Void = {}) {
        self.model = model
        self.isSelected = isSelected
        self.onSelect = onSelect
    }

    public var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 5) {
                // Main Syrtis-Style Row
                HStack(alignment: .firstTextBaseline) {
                    // Left Column: Dot + Model Name + Percentage
                    HStack(spacing: 7) {
                        Circle()
                            .fill(model.color)
                            .frame(width: 7, height: 7)

                        Text(model.displayName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        Text(String(format: "%.1f%%", model.percentageOfTotal))
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Right Column: Total Tokens
                    Text(TrackerViewModel.formatCompact(model.totalTokens))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }

                // Sub-Row: In / Out / CR metrics + Cost
                HStack(alignment: .firstTextBaseline) {
                    HStack(spacing: 6) {
                        HStack(spacing: 2) {
                            Text("In")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            Text(TrackerViewModel.formatCompact(model.inputTokens))
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(.primary)
                        }

                        HStack(spacing: 2) {
                            Text("Out")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            Text(TrackerViewModel.formatCompact(model.outputTokens))
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(.orange)
                        }

                        HStack(spacing: 2) {
                            Text("CR")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            Text(TrackerViewModel.formatCompact(model.cacheReadTokens))
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(.purple)
                        }

                        if model.cacheHitPercentage > 0 {
                            Text("(\(Int(model.cacheHitPercentage))% hit)")
                                .font(.system(size: 8))
                                .foregroundColor(.purple.opacity(0.8))
                        }
                    }

                    Spacer()

                    // Cost in bold green (like Syrtis)
                    Text(TrackerViewModel.formatCurrency(model.estimatedCost))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.green)
                }

                // Quota & Limits Indicator (if available)
                if let fiveHour = model.fiveHourQuota {
                    HStack(spacing: 6) {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(fiveHour.gaugeColor)
                                .frame(width: 5, height: 5)
                            Text("5h: \(Int(fiveHour.remainingPercent.rounded()))% left")
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .foregroundColor(fiveHour.gaugeColor)
                        }

                        if let weekly = model.weeklyQuota {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(weekly.gaugeColor)
                                    .frame(width: 5, height: 5)
                                Text("Wk: \(Int(weekly.remainingPercent.rounded()))% left")
                                    .font(.system(size: 9, weight: .medium, design: .rounded))
                                    .foregroundColor(weekly.gaugeColor)
                            }
                        }

                        Spacer()

                        if !fiveHour.resetCountdownText.isEmpty {
                            Text(fiveHour.resetCountdownText)
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 1)
                }
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? model.color.opacity(0.12) : Color(nsColor: .controlBackgroundColor).opacity(0.45))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? model.color : Color.primary.opacity(0.06), lineWidth: isSelected ? 1.5 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

public struct ModelsView: View {
    @ObservedObject var tracker: TrackerViewModel

    public init(tracker: TrackerViewModel) {
        self.tracker = tracker
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 10) {
                // Section 1: Active Model Limits & Quotas
                ModelLimitsSectionView(tracker: tracker)

                Divider()
                    .padding(.horizontal, 14)

                // Section 2: Models by cost
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Models by cost")
                                .font(.system(size: 13, weight: .bold))
                            Text("\(tracker.modelUsages.count) models • \(TrackerViewModel.formatCompact(tracker.totalTokens)) • \(TrackerViewModel.formatCurrency(tracker.totalCost))")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            if tracker.selectedModelFilter != nil {
                                Button(action: { tracker.selectedModelFilter = nil }) {
                                    HStack(spacing: 3) {
                                        Text("Clear filter")
                                            .font(.system(size: 9, weight: .medium))
                                        Image(systemName: "xmark")
                                            .font(.system(size: 7, weight: .bold))
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.15))
                                    .foregroundColor(.blue)
                                    .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                            } else {
                                Text("LiteLLM rates")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 14)

                    // Multi-colored distribution bar
                    if !tracker.modelUsages.isEmpty {
                        GeometryReader { geo in
                            HStack(spacing: 1.5) {
                                ForEach(tracker.modelUsages) { model in
                                    let width = max(2, (geo.size.width - CGFloat((tracker.modelUsages.count - 1) * 2)) * CGFloat(model.percentageOfTotal / 100.0))
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(model.color)
                                        .frame(width: width, height: 5)
                                }
                            }
                        }
                        .frame(height: 5)
                        .padding(.horizontal, 14)
                    }

                    // List of models
                    if tracker.modelUsages.isEmpty {
                        VStack(spacing: 6) {
                            Image(systemName: "cpu")
                                .font(.system(size: 26))
                                .foregroundColor(.secondary.opacity(0.4))
                            Text("No model usage recorded for \(tracker.selectedPeriod.rawValue.lowercased())")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else {
                        LazyVStack(spacing: 6) {
                            ForEach(tracker.modelUsages) { model in
                                ModelUsageRowView(
                                    model: model,
                                    isSelected: tracker.selectedModelFilter == model.id,
                                    onSelect: {
                                        if tracker.selectedModelFilter == model.id {
                                            tracker.selectedModelFilter = nil
                                        } else {
                                            tracker.selectedModelFilter = model.id
                                            tracker.currentView = .sessions
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 14)
                    }
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Quota & Limits Section

public struct ModelLimitsSectionView: View {
    @ObservedObject var tracker: TrackerViewModel

    public init(tracker: TrackerViewModel) {
        self.tracker = tracker
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.blue)
                    Text("ACTIVE LIMITS & QUOTA")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .tracking(0.5)
                }

                Spacer()

                if tracker.isFetchingQuota {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 14, height: 14)
                } else {
                    Button(action: { tracker.refreshQuota() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Refresh quota limits from agy")
                }
            }
            .padding(.horizontal, 14)

            if let snapshot = tracker.quotaSnapshot, !snapshot.groups.isEmpty {
                VStack(spacing: 8) {
                    ForEach(snapshot.groups) { group in
                        QuotaGroupCardView(group: group)
                    }
                }
                .padding(.horizontal, 14)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text(tracker.isFetchingQuota ? "Querying Antigravity quota..." : "Quota limits available when Antigravity CLI is active")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.04)))
                .padding(.horizontal, 14)
            }
        }
    }
}

public struct QuotaGroupCardView: View {
    let group: QuotaGroup

    public init(group: QuotaGroup) {
        self.group = group
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: group.iconName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(group.tintColor)

                Text(group.name)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.primary)

                if let desc = group.description {
                    Text("• " + desc.replacingOccurrences(of: "Models within this group: ", with: ""))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }

            VStack(spacing: 6) {
                ForEach(group.buckets) { bucket in
                    QuotaBucketRowView(bucket: bucket)
                }
            }
        }
        .padding(9)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

public struct QuotaBucketRowView: View {
    let bucket: QuotaBucket

    public init(bucket: QuotaBucket) {
        self.bucket = bucket
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(bucket.windowDisplayName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)

                Spacer()

                HStack(spacing: 4) {
                    Text("\(Int(bucket.remainingPercent.rounded()))% left")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(bucket.gaugeColor)

                    Text("(\(Int(bucket.usedPercent.rounded()))% used)")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.8))
                }
            }

            // Fill Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 5)

                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(bucket.gaugeColor)
                        .frame(width: max(2, geo.size.width * CGFloat(bucket.remainingFraction)), height: 5)
                }
            }
            .frame(height: 5)

            // Reset Subtext
            HStack {
                if !bucket.resetCountdownText.isEmpty {
                    Text(bucket.resetCountdownText)
                        .font(.system(size: 8.5))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if let raw = bucket.rawResetTime, let formatted = formatResetDate(raw) {
                    Text(formatted)
                        .font(.system(size: 8))
                        .foregroundColor(.secondary.opacity(0.6))
                }
            }
        }
    }

    private func formatResetDate(_ raw: String) -> String? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        guard let date = iso.date(from: raw) else { return nil }
        let f = DateFormatter()
        f.dateFormat = "MMM d, HH:mm"
        return f.string(from: date)
    }
}

public struct ModelDistributionBar: View {
    @ObservedObject var tracker: TrackerViewModel

    public init(tracker: TrackerViewModel) {
        self.tracker = tracker
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("MODEL DISTRIBUTION")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(0.5)

                Spacer()

                Button(action: {
                    tracker.currentView = .models
                }) {
                    Text("View all (\(tracker.modelUsages.count)) →")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }

            // Stacked bar
            GeometryReader { geo in
                HStack(spacing: 1.5) {
                    ForEach(tracker.modelUsages) { model in
                        let width = max(2, (geo.size.width - CGFloat((tracker.modelUsages.count - 1) * 2)) * CGFloat(model.percentageOfTotal / 100.0))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(model.color)
                            .frame(width: width, height: 6)
                    }
                }
            }
            .frame(height: 6)

            // Legend chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(tracker.modelUsages) { model in
                        Button(action: {
                            tracker.selectedModelFilter = model.id
                            tracker.currentView = .sessions
                        }) {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(model.color)
                                    .frame(width: 5, height: 5)

                                Text(model.displayName)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.primary)

                                Text(String(format: "%.0f%%", model.percentageOfTotal))
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
