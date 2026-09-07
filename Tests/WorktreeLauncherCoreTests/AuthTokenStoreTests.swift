import Foundation
import Testing
@testable import WorktreeLauncherCore

@Suite("Auth token store")
struct AuthTokenStoreTests {
    @Test("creates stable owner-only token")
    func createsStableOwnerOnlyToken() throws {
        let root = try temporaryDirectory()
        let url = root.appendingPathComponent("token")
        let store = AuthTokenStore(tokenURL: url)

        let first = try store.loadOrCreateToken()
        let second = try store.loadOrCreateToken()

        #expect(first == second)
        #expect(first.count >= 32)
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        #expect(attrs[.posixPermissions] as? Int == 0o600)
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
