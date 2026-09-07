import Foundation
import ServiceManagement

public final class LoginItemController: ObservableObject, @unchecked Sendable {
    public init() {}

    public var statusDescription: String {
        if FileManager.default.fileExists(atPath: Self.launchAgentURL.path) {
            return "enabled (LaunchAgent)"
        }
        switch SMAppService.mainApp.status {
        case .enabled:
            return "enabled"
        case .requiresApproval:
            return "requires approval"
        case .notRegistered:
            return "not registered"
        case .notFound:
            return "not found"
        @unknown default:
            return "unknown"
        }
    }

    public func ensureEnabled() {
        guard SMAppService.mainApp.status == .notRegistered else { return }
        try? SMAppService.mainApp.register()
    }

    public func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    private static var launchAgentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("io.github.mohsen89z.worktree-launcher.plist")
    }
}
