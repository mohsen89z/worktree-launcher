import Foundation
import Testing
@testable import WorktreeLauncherCore

@Suite("JSON router", .serialized)
struct JsonRouterTests {
    @Test("health does not require auth")
    func healthDoesNotRequireAuth() throws {
        let fixture = try RouterFixture()
        let response = try fixture.router.handle(HttpRequest(method: "GET", path: "/health", headers: [:], body: Data()))
        #expect(response.status == 200)
    }

    @Test("apps require bearer auth")
    func appsRequireBearerAuth() throws {
        let fixture = try RouterFixture()
        let response = try fixture.router.handle(HttpRequest(method: "GET", path: "/apps", headers: [:], body: Data()))
        #expect(response.status == 401)
    }

    @Test("registers and removes app through API")
    func registersAndRemovesAppThroughAPI() throws {
        let fixture = try RouterFixture()
        let body = try JSONEncoder().encode(RegisterAppRequest(name: "web-app", cwd: fixture.root.path, command: "echo ok", url: "http://localhost:3000", ports: [], tags: ["test"], start: false))

        let created = try fixture.router.handle(HttpRequest(method: "POST", path: "/apps", headers: fixture.authHeaders, body: body))
        #expect(created.status == 201)
        let record = try JSONDecoder.launcher.decode(AppRecord.self, from: created.body)

        let removed = try fixture.router.handle(HttpRequest(method: "DELETE", path: "/apps/\(record.id)", headers: fixture.authHeaders, body: Data()))
        #expect(removed.status == 204)
        #expect(FileManager.default.fileExists(atPath: fixture.root.path))
    }

    @Test("returns log tail")
    func returnsLogTail() throws {
        let fixture = try RouterFixture()
        let record = try fixture.registry.register(RegisterAppRequest(name: "logs", cwd: fixture.root.path, command: "echo ok", url: nil, ports: [], tags: [], start: false))
        try "a\nb\nc\n".write(toFile: record.logPath, atomically: true, encoding: .utf8)

        let response = try fixture.router.handle(HttpRequest(method: "GET", path: "/apps/\(record.id)/logs?lines=2", headers: fixture.authHeaders, body: Data()))

        #expect(response.status == 200)
        #expect(String(data: response.body, encoding: .utf8)?.contains("b\nc") == true)
    }
}

private struct RouterFixture {
    let root: URL
    let registry: AppRegistry
    let router: JsonRouter
    let authHeaders: [String: String]

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        registry = try AppRegistry(storageURL: root.appendingPathComponent("registry.json"), logsDirectory: root.appendingPathComponent("logs"))
        let manager = ProcessManager(registry: registry)
        let token = "test-token"
        router = JsonRouter(registry: registry, processManager: manager, logStore: LogStore(directory: root.appendingPathComponent("logs")), token: token)
        authHeaders = ["authorization": "Bearer \(token)"]
    }
}
