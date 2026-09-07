import Foundation
import Testing
@testable import WorktreeLauncherCore

@Suite("App registry")
struct AppRegistryTests {
    @Test("registers and persists record")
    func registersAndPersistsRecord() throws {
        let root = try temporaryDirectory()
        let registry = try AppRegistry(storageURL: root.appendingPathComponent("registry.json"), logsDirectory: root.appendingPathComponent("logs"))

        let record = try registry.register(RegisterAppRequest(
            name: "web-app",
            cwd: FileManager.default.currentDirectoryPath,
            command: "npm run dev",
            url: "http://localhost:3000",
            ports: [],
            tags: ["test"],
            start: false
        ))

        #expect(record.name == "web-app")
        #expect(record.status == .stopped)
        #expect(record.logPath.contains(record.id))

        let reloaded = try AppRegistry(storageURL: root.appendingPathComponent("registry.json"), logsDirectory: root.appendingPathComponent("logs"))
        #expect(try reloaded.list().map(\.id) == [record.id])
    }

    @Test("remove deletes only record")
    func removeDeletesOnlyRecord() throws {
        let root = try temporaryDirectory()
        let registry = try AppRegistry(storageURL: root.appendingPathComponent("registry.json"), logsDirectory: root.appendingPathComponent("logs"))
        let cwd = FileManager.default.currentDirectoryPath
        let record = try registry.register(RegisterAppRequest(name: "app", cwd: cwd, command: "sleep 1", url: nil, ports: [], tags: [], start: false))

        try registry.remove(id: record.id)

        #expect(try registry.list().isEmpty)
        #expect(FileManager.default.fileExists(atPath: cwd))
    }

    @Test("the same app name in two worktrees requires an exact id")
    func ambiguousNamesRequireExactID() throws {
        let root = try temporaryDirectory()
        let worktreeA = try temporaryDirectory()
        let worktreeB = try temporaryDirectory()
        let registry = try AppRegistry(storageURL: root.appendingPathComponent("registry.json"), logsDirectory: root.appendingPathComponent("logs"))
        let first = try registry.register(RegisterAppRequest(name: "web-app", cwd: worktreeA.path, command: "sleep 1", url: nil, ports: [], tags: [], start: false))
        _ = try registry.register(RegisterAppRequest(name: "web-app", cwd: worktreeB.path, command: "sleep 2", url: nil, ports: [], tags: [], start: false))

        do {
            _ = try registry.resolveID("web-app")
            Issue.record("Expected ambiguous name error")
        } catch let error as AppRegistry.RegistryError {
            #expect(error == .ambiguousName("web-app"))
        }
        #expect(try registry.resolveID(first.id) == first.id)
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
