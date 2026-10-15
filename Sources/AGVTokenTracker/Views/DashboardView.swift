import SwiftUI
import AppKit

public struct DashboardView: View {
    @ObservedObject var tracker: TrackerViewModel
    @State private var showingSettings = false

    public init(tracker: TrackerViewModel) {
        self.tracker = tracker
    }

    public var body: some View {
        VStack(spacing: 12) {
            // Header Bar
            HStack(spacing: 8) {
                Image(systemName: "bolt.shield.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text("Antigravity 2.0")
                        .font(.system(size: 13, weight: .bold))
                    Text("Token & Cost Monitor")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer()

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

                Button(action: { showingSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Settings")
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)

            // Period Selector
            Picker("", selection: $tracker.selectedPeriod) {
                ForEach(TimePeriod.allCases) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 14)

            // Main Hero Card
            HeroStatsCard(
                totalTokens: tracker.totalTokens,
                totalCost: tracker.totalCost,
                periodName: tracker.selectedPeriod.rawValue
            )
            .padding(.horizontal, 14)

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

            // Recent Sessions Section
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("SESSIONS IN THIS PERIOD")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .tracking(0.5)

                    Spacer()

                    Text("\(tracker.filteredSessions.count) active")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 14)

                if tracker.filteredSessions.isEmpty {
                    VStack(spacing: 4) {
                        Image(systemName: "clock.badge.questionmark")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary.opacity(0.5))
                            .padding(.top, 8)
                        Text("No sessions recorded for \(tracker.selectedPeriod.rawValue.lowercased())")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 70)
                } else {
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(spacing: 6) {
                            ForEach(tracker.filteredSessions.prefix(12)) { session in
                                SessionRowView(session: session)
                            }
                        }
                        .padding(.horizontal, 14)
                    }
                    .frame(maxHeight: 140)
                }
            }

            Divider()

            // Footer Bar
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
            .padding(.bottom, 10)
        }
        .frame(width: 360)
        .sheet(isPresented: $showingSettings) {
            SettingsSheet(tracker: tracker)
        }
    }
}
