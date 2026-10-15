import SwiftUI
import AppKit

public struct DashboardView: View {
    @ObservedObject var tracker: TrackerViewModel

    public init(tracker: TrackerViewModel) {
        self.tracker = tracker
    }

    public var body: some View {
        ZStack {
            if tracker.isShowingSettings {
                SettingsSheet(tracker: tracker, onClose: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        tracker.isShowingSettings = false
                    }
                })
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
            } else {
                mainDashboardContent
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
        }
        .frame(width: 380, height: 620)
        .animation(.easeInOut(duration: 0.18), value: tracker.isShowingSettings)
    }

    @ViewBuilder
    private var mainDashboardContent: some View {
        VStack(spacing: 0) {
            // Pinned Top Controls
            VStack(spacing: 7) {
                // Header Bar
                HStack(spacing: 8) {
                    Image(systemName: tracker.selectedSurface == .all ? "bolt.shield.fill" : tracker.selectedSurface.iconName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: tracker.selectedSurface == .all ? [.yellow, .orange] : [tracker.selectedSurface.badgeColor, tracker.selectedSurface.badgeColor.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    VStack(alignment: .leading, spacing: 1) {
                        Text(tracker.selectedSurface == .all ? "Antigravity Unified" : tracker.selectedSurface.rawValue)
                            .font(.system(size: 13, weight: .bold))
                        Text("Token & Cost Monitor")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Quick Toggle for Menu Bar display mode (Tokens vs Cost)
                    Button(action: {
                        if tracker.displayMode == .tokens {
                            tracker.displayMode = .cost
                        } else {
                            tracker.displayMode = .tokens
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "brain.fill")
                                .font(.system(size: 8))
                            Text(tracker.displayMode == .cost ? "Cost" : "Tokens")
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(Color.primary.opacity(0.08))
                        .cornerRadius(5)
                        .foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)
                    .help("Toggle menu bar title between Tokens and Cost")

                    if tracker.isScanning {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 16, height: 16)
                    } else {
                        Button(action: { tracker.refresh() }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Refresh now")
                    }

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            tracker.isShowingSettings = true
                        }
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Settings")
                }

                // 1. Top-Level Lens Switcher (Overview | Models | Sessions)
                Picker("Lens", selection: $tracker.currentView) {
                    ForEach(AppViewTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                // 2. Surface Selector (All | 2.0 | CLI | IDE)
                Picker("Surface", selection: $tracker.selectedSurface) {
                    ForEach(AppSurface.allCases) { surface in
                        Text(surface.shortLabel).tag(surface)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                // 3. Period Selector (Today | Yesterday | This Week | This Month | All Time)
                Picker("Period", selection: $tracker.selectedPeriod) {
                    ForEach(TimePeriod.allCases) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 6)

            Divider()

            // Active View Lens (Fills middle area, pinned to top)
            Group {
                switch tracker.currentView {
                case .overview:
                    overviewView
                case .models:
                    ModelsView(tracker: tracker)
                        .padding(.top, 8)
                case .sessions:
                    SessionsListView(tracker: tracker)
                        .padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            Divider()

            // Pinned Footer Bar
            HStack(spacing: 8) {
                Circle()
                    .fill(tracker.isPulsing ? Color.green : Color.secondary.opacity(0.4))
                    .frame(width: 6, height: 6)

                Text("Live file watcher active")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .font(.system(size: 11))
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Overview View
    @ViewBuilder
    private var overviewView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 10) {
                // Surface Breakdown (Visible when "All" is active)
                if tracker.selectedSurface == .all {
                    SurfaceBreakdownView(tracker: tracker)
                }

                // Main Hero Card
                HeroStatsCard(
                    totalTokens: tracker.totalTokens,
                    totalCost: tracker.totalCost,
                    periodName: tracker.selectedPeriod.rawValue
                )
                .padding(.horizontal, 14)

                // Model Distribution Bar (Visible if model usage data exists)
                if !tracker.modelUsages.isEmpty {
                    ModelDistributionBar(tracker: tracker)
                        .padding(.horizontal, 14)
                }

                // 2x2 Metric Breakdown Cards
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        MetricCardView(
                            title: "Input Tokens",
                            value: TrackerViewModel.formatNumber(tracker.totalInputTokens),
                            subtitle: "Fresh context & prompt",
                            icon: "arrow.down.circle.fill",
                            iconColor: .blue
                        )

                        MetricCardView(
                            title: "Cache Read",
                            value: TrackerViewModel.formatNumber(tracker.totalCacheReadTokens),
                            subtitle: "Context cache hit",
                            icon: "sparkles",
                            iconColor: .purple,
                            badgeText: "75% off"
                        )
                    }

                    HStack(spacing: 8) {
                        MetricCardView(
                            title: "Output Tokens",
                            value: TrackerViewModel.formatNumber(tracker.totalOutputTokens),
                            subtitle: "Reasoning & response",
                            icon: "arrow.up.circle.fill",
                            iconColor: .orange
                        )

                        MetricCardView(
                            title: "Cache Efficiency",
                            value: String(format: "%.1f%%", tracker.cacheHitPercentage),
                            subtitle: "Cached / prompt ratio",
                            icon: "leaf.fill",
                            iconColor: .green
                        )
                    }
                }
                .padding(.horizontal, 14)

                // Active Model Quota & Limits
                ActiveQuotaSummaryView(tracker: tracker)

                // Recent Sessions Section Preview
                RecentSessionsSection(tracker: tracker)
            }
            .padding(.top, 8)
            .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

public struct ActiveQuotaSummaryView: View {
    @ObservedObject var tracker: TrackerViewModel

    public init(tracker: TrackerViewModel) {
        self.tracker = tracker
    }

    public var body: some View {
        if let snapshot = tracker.quotaSnapshot, !snapshot.groups.isEmpty {
            Button(action: {
                tracker.currentView = .models
            }) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        HStack(spacing: 5) {
                            Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.blue)
                            Text("ACTIVE QUOTA & LIMITS")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                                .tracking(0.5)
                        }

                        Spacer()

                        HStack(spacing: 3) {
                            Text("View all limits")
                                .font(.system(size: 9, weight: .medium))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 7, weight: .bold))
                        }
                        .foregroundColor(.blue)
                    }

                    HStack(spacing: 12) {
                        ForEach(snapshot.groups) { group in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(group.tintColor)
                                        .frame(width: 5, height: 5)
                                    Text(group.name.components(separatedBy: " ").first ?? group.name)
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.primary)
                                }

                                if let fiveH = group.fiveHourBucket {
                                    HStack(spacing: 3) {
                                        Text("5h: \(Int(fiveH.remainingPercent.rounded()))%")
                                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                                            .foregroundColor(fiveH.gaugeColor)

                                        if let wk = group.weeklyBucket {
                                            Text("• Wk: \(Int(wk.remainingPercent.rounded()))%")
                                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                                .foregroundColor(wk.gaugeColor)
                                        }
                                    }
                                }
                            }
                        }
                        Spacer()
                    }
                }
                .padding(9)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.45))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
        }
    }
}

public struct RecentSessionsSection: View {
    @ObservedObject var tracker: TrackerViewModel

    public init(tracker: TrackerViewModel) {
        self.tracker = tracker
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("RECENT SESSIONS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(0.5)

                Spacer()

                Button(action: {
                    tracker.currentView = .sessions
                }) {
                    Text("View all (\(tracker.filteredSessions.count)) →")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)

            if tracker.filteredSessions.isEmpty {
                VStack(spacing: 4) {
                    Image(systemName: "clock.badge.questionmark")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary.opacity(0.4))
                        .padding(.top, 4)
                    Text("No sessions recorded for \(tracker.selectedPeriod.rawValue.lowercased())")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 60)
            } else {
                VStack(spacing: 5) {
                    ForEach(tracker.filteredSessions.prefix(4)) { session in
                        SessionRowView(session: session)
                    }
                }
                .padding(.horizontal, 14)
            }
        }
    }
}

public struct SessionsListView: View {
    @ObservedObject var tracker: TrackerViewModel

    public init(tracker: TrackerViewModel) {
        self.tracker = tracker
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let filter = tracker.selectedModelFilter {
                    HStack(spacing: 4) {
                        Text("Model filter:")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)

                        Button(action: { tracker.selectedModelFilter = nil }) {
                            HStack(spacing: 3) {
                                Text(filter)
                                    .font(.system(size: 9, weight: .semibold))
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
                        .help("Clear model filter")
                    }
                } else {
                    Text("SESSIONS IN THIS PERIOD")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .tracking(0.5)
                }

                Spacer()

                Text("\(tracker.filteredSessions.count) active")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)

            if tracker.filteredSessions.isEmpty {
                VStack(spacing: 6) {
                    Spacer()
                    Image(systemName: "clock.badge.questionmark")
                        .font(.system(size: 26))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("No sessions recorded for \(tracker.selectedPeriod.rawValue.lowercased())")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 6) {
                        ForEach(tracker.filteredSessions) { session in
                            SessionRowView(session: session)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 2)
                    .padding(.bottom, 6)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

public struct SurfaceBreakdownView: View {
    @ObservedObject var tracker: TrackerViewModel

    private let surfaces: [AppSurface] = [.desktop, .cli, .ide]

    public init(tracker: TrackerViewModel) {
        self.tracker = tracker
    }

    public var body: some View {
        HStack(spacing: 6) {
            ForEach(surfaces) { surface in
                let metrics = tracker.surfaceMetrics(for: surface)
                Button(action: {
                    tracker.selectedSurface = surface
                }) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(surface.badgeColor)
                                .frame(width: 6, height: 6)
                            Text(surface.shortLabel)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: surface.iconName)
                                .font(.system(size: 9))
                                .foregroundColor(surface.badgeColor)
                        }

                        Text(TrackerViewModel.formatCompact(metrics.tokens))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)

                        HStack {
                            Text(TrackerViewModel.formatCurrency(metrics.cost))
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundColor(.green)
                            Spacer()
                            Text("\(metrics.sessionsCount) ses")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(surface.badgeColor.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
                .help("Filter to \(surface.rawValue)")
            }
        }
        .padding(.horizontal, 14)
    }
}
