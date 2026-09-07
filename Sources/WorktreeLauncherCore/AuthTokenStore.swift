import Foundation

public struct AuthTokenStore: Sendable {
    public let tokenURL: URL

    public init(tokenURL: URL) {
        self.tokenURL = tokenURL
    }

    public static func defaultTokenURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Worktree Launcher", isDirectory: true)
            .appendingPathComponent("token")
    }

    public func loadOrCreateToken() throws -> String {
        if FileManager.default.fileExists(atPath: tokenURL.path) {
            return try String(contentsOf: tokenURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        try FileManager.default.createDirectory(at: tokenURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let token = UUID().uuidString.replacingOccurrences(of: "-", with: "") + UUID().uuidString.replacingOccurrences(of: "-", with: "")
        try token.write(to: tokenURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tokenURL.path)
        return token
    }
}
