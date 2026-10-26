import SwiftUI
import AppKit

public struct SettingsSheet: View {
    @ObservedObject var tracker: TrackerViewModel
    var onClose: () -> Void = {}

    public init(tracker: TrackerViewModel, onClose: @escaping () -> Void = {}) {
        self.tracker = tracker
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: {
                    tracker.isShowingSettings = false
                    onClose()
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .bold))
                        Text("Back")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .frame(width: 50, alignment: .leading)

                Spacer()

                HStack(spacing: 5) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.accentColor)
                    Text("Settings")
                        .font(.system(size: 13, weight: .bold))
                }

                Spacer()

                // Balance the Back button so title remains perfectly centered
                Color.clear
                    .frame(width: 50, height: 1)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Divider()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    // 1. Menu Bar Display Mode
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("MENU BAR DISPLAY")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                                .tracking(0.5)

                            Spacer()

                            // Live preview of menu bar
                            HStack(spacing: 4) {
                                Image(systemName: "brain.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.primary)

                                if tracker.displayMode != .compact && !tracker.menuBarTitle.isEmpty {
                                    Text(tracker.menuBarTitle)
                                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                                        .foregroundColor(.primary)
                                }
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.primary.opacity(0.06))
                            .cornerRadius(5)
                        }

                        Picker("Display Mode", selection: $tracker.displayMode) {
                            Text("Tokens (\(TrackerViewModel.formatCompact(tracker.totalTokens)))").tag(StatusDisplayMode.tokens)
                            Text("Cost (\(TrackerViewModel.formatCurrency(tracker.totalCost)))").tag(StatusDisplayMode.cost)
                            Text("Icon Only").tag(StatusDisplayMode.compact)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()

                        Text("Choose whether the top menu bar shows token count, estimated cost in USD, or only the brain icon.")
                            .font(.system(size: 9.5))
                            .foregroundColor(.secondary)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                            )
                    )

                    // 2. Monitored Surfaces
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Monitored Surfaces & Storage")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)

                        VStack(spacing: 6) {
                            SurfaceStatusRow(
                                surface: .desktop,
                                path: tracker.customBrainPath.isEmpty ? "~/.gemini/antigravity/brain" : tracker.customBrainPath,
                                url: TranscriptScanner.shared.resolveBrainDirectory(
                                    customPath: tracker.customBrainPath.isEmpty ? nil : tracker.customBrainPath
                                )
                            )

                            SurfaceStatusRow(
                                surface: .cli,
                                path: "~/.gemini/antigravity-cli",
                                url: AppSurface.cli.defaultDirectoryURL
                            )

                            SurfaceStatusRow(
                                surface: .ide,
                                path: "~/.gemini/antigravity-ide",
                                url: AppSurface.ide.defaultDirectoryURL
                            )
                        }

                        // Custom 2.0 path input
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Custom Antigravity 2.0 brain directory (optional):")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)

                            HStack {
                                TextField(
                                    "Default: ~/.gemini/antigravity/brain",
                                    text: $tracker.customBrainPath
                                )
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 10, design: .monospaced))

                                if !tracker.customBrainPath.isEmpty {
                                    Button("Reset") {
                                        tracker.customBrainPath = ""
                                        tracker.startWatcher()
                                        tracker.refresh()
                                    }
                                    .font(.system(size: 10))
                                }
                            }
                        }
                        .padding(.top, 2)
                    }

                    // 3. Pricing Engine
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Pricing Engine")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Source: LiteLLM Open Database")
                                    .font(.system(size: 11, weight: .medium))
                                if let date = tracker.pricingSyncDate {
                                    Text("Last synced: \(date.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Using built-in Gemini Flash/Pro offline rates")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            Button("Sync Rates") {
                                Task {
                                    await PricingService.shared.fetchRemotePricing()
                                    await MainActor.run {
                                        tracker.pricingSyncDate = PricingService.shared.lastSyncDate
                                        tracker.refresh()
                                    }
                                }
                            }
                            .font(.system(size: 11))
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            Divider()

            // Footer / Actions
            HStack(spacing: 8) {
                Text("AGYTokenTracker v1.0.0")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Text("•")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.4))

                Button(action: {
                    if let url = URL(string: "https://github.com/rsimenok/agy-token-traker") {
                        NSWorkspace.shared.open(url)
                        dismissWindow()
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 9))
                        Text("GitHub")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .help("Open GitHub Repository")

                Spacer()

                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Image(systemName: "power")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Quit App")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func dismissWindow() {
        (NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }))?.close()
        NSApp.deactivate()
    }
}

public struct SurfaceStatusRow: View {
    let surface: AppSurface
    let path: String
    let url: URL

    public init(surface: AppSurface, path: String, url: URL) {
        self.surface = surface
        self.path = path
        self.url = url
    }

    private var exists: Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: surface.iconName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(surface.badgeColor)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(surface.rawValue)
                        .font(.system(size: 11, weight: .semibold))

                    if exists {
                        Text("Active")
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.green.opacity(0.15))
                            .foregroundColor(.green)
                            .cornerRadius(3)
                    } else {
                        Text("Not Found")
                            .font(.system(size: 8, weight: .medium))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.12))
                            .foregroundColor(.secondary)
                            .cornerRadius(3)
                    }
                }

                Text(path)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            if exists {
                Button(action: {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
                    (NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }))?.close()
                    NSApp.deactivate()
                }) {
                    Image(systemName: "folder")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Open in Finder")
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
    }
}
