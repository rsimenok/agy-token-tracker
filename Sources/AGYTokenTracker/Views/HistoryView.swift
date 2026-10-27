import SwiftUI
import Charts

public struct HistoryView: View {
    @ObservedObject var tracker: TrackerViewModel
    @State private var selectedMonthFilter: Int? = nil

    public init(tracker: TrackerViewModel) {
        self.tracker = tracker
    }

    private var annualMetrics: (tokens: Int, cost: Double, sessions: Int, activeMonths: Int, cacheHitRatio: Double) {
        tracker.annualHistoryMetrics(for: tracker.selectedHistoryYear)
    }

    private var yearRecords: [MonthlyRecord] {
        tracker.historyRecords(for: tracker.selectedHistoryYear)
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                // 1. Year Selector Header
                yearSelectorBar

                // 2. Annual Hero Summary
                annualHeroCard

                // 3. Infographics: Monthly Spending Trend Bar Chart
                monthlyCostChartSection

                // 4. Monthly Cards Breakdown
                monthlyBreakdownList
            }
            .padding(.horizontal, 14)
            .padding(.top, 4)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - 1. Year Selector Bar
    private var yearSelectorBar: some View {
        HStack(spacing: 8) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.18)) {
                    tracker.selectedHistoryYear -= 1
                    selectedMonthFilter = nil
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Previous year")

            Text(String(tracker.selectedHistoryYear))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Button(action: {
                withAnimation(.easeInOut(duration: 0.18)) {
                    tracker.selectedHistoryYear += 1
                    selectedMonthFilter = nil
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Next year")

            Spacer()

            if tracker.selectedSurface != .all {
                HStack(spacing: 4) {
                    Circle()
                        .fill(tracker.selectedSurface.badgeColor)
                        .frame(width: 6, height: 6)
                    Text(tracker.selectedSurface.shortLabel)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(tracker.selectedSurface.badgeColor.opacity(0.12))
                .cornerRadius(4)
            }

            Text("\(annualMetrics.activeMonths) active mo")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }

    // MARK: - 2. Annual Hero Summary
    private var annualHeroCard: some View {
        VStack(spacing: 8) {
            HStack {
                Text(verbatim: "\(tracker.selectedHistoryYear) ANNUAL SUMMARY")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(0.8)
                Spacer()
                Text("TOTAL SPEND")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(0.5)
            }

            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(TrackerViewModel.formatCompact(annualMetrics.tokens))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("\(annualMetrics.sessions) sessions • \(Int(annualMetrics.cacheHitRatio * 100))% cache hit")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Text(TrackerViewModel.formatCurrency(annualMetrics.cost))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                    Text("USD")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.8))
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
    }

    // MARK: - 3. Infographics: Monthly Cost Bar Chart (Swift Charts)
    private var monthlyCostChartSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("MONTHLY SPENDING TREND")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(0.5)

                Spacer()

                if let month = selectedMonthFilter {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedMonthFilter = nil
                        }
                    }) {
                        HStack(spacing: 3) {
                            Text("Month \(month)")
                                .font(.system(size: 9, weight: .semibold))
                            Image(systemName: "xmark")
                                .font(.system(size: 7, weight: .bold))
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundColor(.accentColor)
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("Tap bar to filter")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.7))
                }
            }

            let chartData = (1...12).map { m -> MonthChartPoint in
                let rec = yearRecords.first { $0.month == m }
                let metrics = rec?.metrics(for: tracker.selectedSurface)
                let cost = metrics?.cost ?? 0.0
                let tokens = metrics?.tokens ?? 0
                return MonthChartPoint(
                    month: m,
                    shortName: monthShortName(m),
                    cost: cost,
                    tokens: tokens
                )
            }

            Chart(chartData) { item in
                BarMark(
                    x: .value("Month", item.shortName),
                    y: .value("Cost", item.cost)
                )
                .foregroundStyle(
                    barGradient(for: item.month, hasData: item.cost > 0)
                )
                .cornerRadius(3)
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { value in
                    AxisValueLabel()
                        .font(.system(size: 8, weight: .medium))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                        .foregroundStyle(Color.secondary.opacity(0.2))
                    AxisValueLabel {
                        if let d = value.as(Double.self) {
                            Text("$\(Int(d))")
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .frame(height: 95)
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
            )
        }
    }

    private func barGradient(for month: Int, hasData: Bool) -> AnyShapeStyle {
        if selectedMonthFilter == month {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        if hasData {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color.green.opacity(0.85), Color.blue.opacity(0.65)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        return AnyShapeStyle(Color.secondary.opacity(0.12))
    }

    // MARK: - 4. Monthly Cards Breakdown
    private var monthlyBreakdownList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("MONTHLY DETAILS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(0.5)

                Spacer()

                Text("\(displayedRecords.count) months")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            if displayedRecords.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 26))
                        .foregroundColor(.secondary.opacity(0.4))
                        .padding(.top, 10)
                    Text(verbatim: "No usage recorded for \(tracker.selectedHistoryYear)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("Historical usage will appear here automatically.")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else {
                VStack(spacing: 8) {
                    ForEach(displayedRecords) { record in
                        MonthlyCardView(
                            record: record,
                            surface: tracker.selectedSurface,
                            isSelected: selectedMonthFilter == record.month,
                            onTap: {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    if selectedMonthFilter == record.month {
                                        selectedMonthFilter = nil
                                    } else {
                                        selectedMonthFilter = record.month
                                    }
                                }
                            }
                        )
                    }
                }
            }
        }
    }

    private var displayedRecords: [MonthlyRecord] {
        let records = yearRecords.filter { rec in
            let m = rec.metrics(for: tracker.selectedSurface)
            return m.tokens > 0 || m.cost > 0
        }
        if let filter = selectedMonthFilter {
            return records.filter { $0.month == filter }
        }
        return records
    }

    private func monthShortName(_ m: Int) -> String {
        let calendar = Calendar.current
        var comps = DateComponents()
        comps.year = tracker.selectedHistoryYear
        comps.month = m
        comps.day = 1
        if let d = calendar.date(from: comps) {
            let f = DateFormatter()
            f.dateFormat = "LLL"
            return f.string(from: d)
        }
        return "\(m)"
    }
}

// MARK: - Supporting Data Structures

private struct MonthChartPoint: Identifiable {
    let month: Int
    let shortName: String
    let cost: Double
    let tokens: Int
    var id: Int { month }
}

// MARK: - Monthly Card View

public struct MonthlyCardView: View {
    let record: MonthlyRecord
    let surface: AppSurface
    let isSelected: Bool
    let onTap: () -> Void

    public init(
        record: MonthlyRecord,
        surface: AppSurface = .all,
        isSelected: Bool = false,
        onTap: @escaping () -> Void
    ) {
        self.record = record
        self.surface = surface
        self.isSelected = isSelected
        self.onTap = onTap
    }

    private var metrics: (tokens: Int, cost: Double, sessions: Int) {
        record.metrics(for: surface)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header Row: Month Name + Total Cost
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(record.monthName)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)

                        Text(String(record.year))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    Text("\(metrics.sessions) sessions • \(record.stepCount) steps")
                        .font(.system(size: 9.5))
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Text(TrackerViewModel.formatCurrency(metrics.cost))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.green)

                    Text(TrackerViewModel.formatCompact(metrics.tokens) + " tokens")
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }

            Divider()
                .opacity(0.4)

            // Token Breakdown: Input / Cache / Output
            HStack(spacing: 6) {
                tokenMetricChip(label: "In", value: record.inputTokens, color: .blue)
                tokenMetricChip(label: "Cache", value: record.cacheReadTokens, color: .purple)
                tokenMetricChip(label: "Out", value: record.outputTokens, color: .orange)

                Spacer()

                HStack(spacing: 3) {
                    Image(systemName: "bolt.shield")
                        .font(.system(size: 8))
                    Text("\(Int(record.cacheHitRatio * 100))% hit")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundColor(.purple)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.purple.opacity(0.12))
                .cornerRadius(4)
            }

            // Surface Breakdown (Expenses by App Surface: 2.0, CLI, IDE)
            let activeSurfaces: [(surface: AppSurface, stat: SurfaceMonthlyStat)] = [AppSurface.desktop, AppSurface.cli, AppSurface.ide].compactMap { s in
                guard let stat = record.surfaceBreakdown[s.rawValue], stat.tokens > 0 || stat.cost > 0 else { return nil }
                return (s, stat)
            }

            if !activeSurfaces.isEmpty {
                HStack(spacing: 5) {
                    ForEach(activeSurfaces, id: \.surface) { item in
                        HStack(spacing: 3.5) {
                            Image(systemName: item.surface.iconName)
                                .font(.system(size: 8.5, weight: .bold))
                                .foregroundColor(item.surface.badgeColor)
                            Text(item.surface.shortLabel)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(item.surface.badgeColor)
                            Text(TrackerViewModel.formatCurrency(item.stat.cost))
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(item.surface.badgeColor.opacity(0.12))
                        .cornerRadius(4)
                    }
                    Spacer()
                }
            }

            // Top Models in this month (if available)
            if !record.modelBreakdown.isEmpty {
                let sortedModels = record.modelBreakdown.values
                    .sorted { $0.cost > $1.cost }
                    .prefix(3)

                HStack(spacing: 4) {
                    ForEach(Array(sortedModels), id: \.canonicalModelId) { mod in
                        HStack(spacing: 3) {
                            Text(mod.displayName)
                                .font(.system(size: 8.5, weight: .medium))
                                .foregroundColor(.primary.opacity(0.85))
                                .lineLimit(1)
                            Text(TrackerViewModel.formatCurrency(mod.cost))
                                .font(.system(size: 8.5, weight: .bold))
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(4)
                    }
                    Spacer()
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(isSelected ? 0.95 : 0.65))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }

    private func tokenMetricChip(label: String, value: Int, color: Color) -> some View {
        HStack(spacing: 2) {
            Text(label + ":")
                .font(.system(size: 8.5, weight: .medium))
                .foregroundColor(.secondary)
            Text(TrackerViewModel.formatCompact(value))
                .font(.system(size: 8.5, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(color.opacity(0.08))
        .cornerRadius(4)
    }
}
