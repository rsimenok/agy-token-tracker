import Foundation
import SwiftUI

public enum AppSurface: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case desktop = "Antigravity 2.0"
    case cli = "CLI"
    case ide = "IDE"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .all: return "square.stack.3d.up.fill"
        case .desktop: return "macwindow"
        case .cli: return "terminal.fill"
        case .ide: return "chevron.left.forwardslash.chevron.right"
        }
    }

    public var badgeColor: Color {
        switch self {
        case .all: return .primary
        case .desktop: return .blue
        case .cli: return .orange
        case .ide: return .purple
        }
    }

    public var shortLabel: String {
        switch self {
        case .all: return "All"
        case .desktop: return "2.0"
        case .cli: return "CLI"
        case .ide: return "IDE"
        }
    }

    public var defaultDirectoryURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch self {
        case .all:
            return home.appendingPathComponent(".gemini", isDirectory: true)
        case .desktop:
            return home.appendingPathComponent(".gemini/antigravity", isDirectory: true)
        case .cli:
            return home.appendingPathComponent(".gemini/antigravity-cli", isDirectory: true)
        case .ide:
            return home.appendingPathComponent(".gemini/antigravity-ide", isDirectory: true)
        }
    }
}
