import Foundation
import Testing
@testable import WorktreeLauncherCore

@Suite("Process manager", .serialized)
struct ProcessManagerTests {
    @Test("start stop and restart update pid")
    func startStopAndRestartUpdatesPid() throws {
        let root = try temporaryDirectory()
        let registry = try AppRegistry(storageURL: root.appendingPathComponent("registry.json"), logsDirectory: root.appendingPathComponent("logs"))
        let manager = ProcessManager(registry: registry)
        let record = try registry.register(RegisterAppRequest(name: "fixture", cwd: root.path, command: "while true; do echo fixture-ready; sleep 1; done", url: nil, ports: [], tags: [], start: false))

        let started = try manager.start(id: record.id)
        #expect(started.status == .running)
        #expect(started.pid != nil)

        let restarted = try manager.restart(id: record.id)
        #expect(restarted.status == .running)
        #expect(started.pid != restarted.pid)

        let stopped = try manager.stop(id: record.id)
        #expect(stopped.status == .stopped)
        #expect(stopped.pid == nil)
    }

    @Test("starts and stops every registered command")
    func startsAndStopsEveryRegisteredCommand() throws {
        let root = try temporaryDirectory()
        let registry = try AppRegistry(storageURL: root.appendingPathComponent("registry.json"), logsDirectory: root.appendingPathComponent("logs"))
        let manager = ProcessManager(registry: registry)
        let record = try registry.register(RegisterAppRequest(
            name: "stack",
            cwd: root.path,
            command: "while true; do echo one; sleep 1; done",
            commands: ["while true; do echo one; sleep 1; done", "while true; do echo two; sleep 1; done"],
            url: nil,
            webApplications: [WebApplication(label: "One", url: "http://localhost:3010"), WebApplication(label: "Two", url: "http://localhost:3011")],
            ports: [],
            tags: [],
            start: false
        ))

        let started = try manager.start(id: record.id)
        #expect(started.pids.count == 2)
        #expect(started.pids.allSatisfy(ProcessTree.isRunning(pid:)))

        let stopped = try manager.stop(id: record.id)
        #expect(stopped.pids.isEmpty)
        #expect(started.pids.allSatisfy { !ProcessTree.isRunning(pid: $0) })
    }

    @Test("logs capture output")
    func logsCaptureOutput() throws {
        let root = try temporaryDirectory()
        let registry = try AppRegistry(storageURL: root.appendingPathComponent("registry.json"), logsDirectory: root.appendingPathComponent("logs"))
        let manager = ProcessManager(registry: registry)
        let record = try registry.register(RegisterAppRequest(name: "logs", cwd: root.path, command: "echo hello-launcher; sleep 1", url: nil, ports: [], tags: [], start: false))

        _ = try manager.start(id: record.id)
        Thread.sleep(forTimeInterval: 1.0)

        let text = try LogStore(directory: root.appendingPathComponent("logs")).tail(id: record.id, lines: 10)
        #expect(text.contains("hello-launcher"))
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
