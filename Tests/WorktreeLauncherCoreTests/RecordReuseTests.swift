import Foundation
import Testing
@testable import WorktreeLauncherCore

@Suite("Record reuse", .serialized)
struct RecordReuseTests {
    @Test("rejects a second record for the same app in the same worktree")
    func rejectsDuplicateRecordForSameWorktree() throws {
        let root = try temporaryDirectory()
        let registry = try AppRegistry(storageURL: root.appendingPathComponent("registry.json"), logsDirectory: root.appendingPathComponent("logs"))
        let existing = try registry.register(RegisterAppRequest(name: "web-app", cwd: root.path, command: "sleep 1", url: nil, ports: [], tags: [], start: false))

        do {
            _ = try registry.register(RegisterAppRequest(name: "web-app", cwd: root.path, command: "sleep 1", url: nil, ports: [], tags: [], start: false))
            Issue.record("Expected duplicate record rejection")
        } catch let error as AppRegistry.RegistryError {
            #expect(error == .alreadyRegistered(id: existing.id, status: AppRuntimeStatus.stopped.rawValue))
            #expect(error.description.contains(existing.id))
            #expect(error.description.contains("restart"))
        }
    }

    @Test("allows a different app in the same worktree and the same app in another worktree")
    func allowsGenuinelyDifferentRecords() throws {
        let root = try temporaryDirectory()
        let other = try temporaryDirectory()
        let registry = try AppRegistry(storageURL: root.appendingPathComponent("registry.json"), logsDirectory: root.appendingPathComponent("logs"))
        _ = try registry.register(RegisterAppRequest(name: "web-app", cwd: root.path, command: "sleep 1", url: nil, ports: [], tags: [], start: false))

        _ = try registry.register(RegisterAppRequest(name: "api", cwd: root.path, command: "sleep 1", url: nil, ports: [], tags: [], start: false))
        _ = try registry.register(RegisterAppRequest(name: "web-app", cwd: other.path, command: "sleep 1", url: nil, ports: [], tags: [], start: false))

        #expect(try registry.list().count == 3)
    }

    @Test("start replaces survivors instead of orphaning them")
    func startReplacesSurvivors() throws {
        let root = try temporaryDirectory()
        let registry = try AppRegistry(storageURL: root.appendingPathComponent("registry.json"), logsDirectory: root.appendingPathComponent("logs"))
        let manager = ProcessManager(registry: registry)
        let record = try registry.register(RegisterAppRequest(
            name: "stack",
            cwd: root.path,
            command: "while true; do sleep 1; done",
            commands: ["while true; do sleep 1; done", "while true; do sleep 1; done"],
            url: nil,
            ports: [],
            tags: [],
            start: false
        ))

        let started = try manager.start(id: record.id)
        #expect(started.pids.count == 2)
        let survivor = started.pids[0]
        ProcessTree.terminateTree(pid: started.pids[1])
        while ProcessTree.isRunning(pid: started.pids[1]) { Thread.sleep(forTimeInterval: 0.05) }

        let restarted = try manager.start(id: record.id)

        #expect(restarted.pids.count == 2)
        #expect(!restarted.pids.contains(survivor))
        #expect(!ProcessTree.isRunning(pid: survivor))
        _ = try manager.stop(id: record.id)
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
