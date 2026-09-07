import Foundation

public enum AppRuntimeStatus: String, Codable, Equatable, Sendable {
    case running
    case stopped
    case failed
    case stale
}
