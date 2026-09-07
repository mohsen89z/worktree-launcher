import Foundation

public final class ProcessManager: @unchecked Sendable {
    private final class RunningProcess {
        let process: Process
        let stdout: Pipe
        let stderr: Pipe

        init(process: Process, stdout: Pipe, stderr: Pipe) {
            self.process = process
            self.stdout = stdout
            self.stderr = stderr
        }
    }

    private let registry: AppRegistry
    private let lock = NSLock()
    private var running: [String: [RunningProcess]] = [:]

    public init(registry: AppRegistry) {
        self.registry = registry
    }

    public func start(id: String) throws -> AppRecord {
        guard var record = try registry.get(id: id) else { throw AppRegistry.RegistryError.notFound(id) }
        let livePids = record.pids.filter(ProcessTree.isRunning(pid:))
        if !livePids.isEmpty, livePids.count == record.commands.count, record.status == .running {
            return record
        }
        // A partially-dead record still holds live processes and their ports. Relaunching without
        // clearing them orphans the survivors, so reap them before starting a fresh set.
        if !livePids.isEmpty {
            record = try stop(id: record.id)
        }
        try registry.assertPortsAvailable(record.ports, excluding: record.id, waitingUpTo: 2)

        let outputURL = URL(fileURLWithPath: record.logPath)
        try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: outputURL.path) {
            FileManager.default.createFile(atPath: outputURL.path, contents: nil)
        }

        let recordID = record.id
        var started: [RunningProcess] = []
        var startedPids: [Int32] = []

        for command in record.commands {
            let stdout = Pipe()
            let stderr = Pipe()
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
            process.arguments = [
                "-c",
                "import os,sys; os.chdir(sys.argv[1]); os.setpgrp(); os.execv('/bin/zsh', ['/bin/zsh', '-lc', sys.argv[2]])",
                record.cwd,
                command,
            ]
            process.currentDirectoryURL = URL(fileURLWithPath: record.cwd, isDirectory: true)
            process.standardOutput = stdout
            process.standardError = stderr

            let append: @Sendable (Data) -> Void = { [weak self] data in
                guard !data.isEmpty else { return }
                Self.append(data: data, to: outputURL)
                guard let text = String(data: data, encoding: .utf8), let detected = UrlDetection.detectURLs(in: text).first else { return }
                do {
                    guard var current = try self?.registry.get(id: recordID), current.url == nil, current.webApplications.isEmpty else { return }
                    current.url = detected
                    current.webApplications = [WebApplication(label: current.name, url: detected)]
                    _ = try self?.registry.update(current)
                } catch {
                    Self.append(data: Data("\n[launcher] failed to update detected URL: \(error)\n".utf8), to: outputURL)
                }
            }

            stdout.fileHandleForReading.readabilityHandler = { handle in append(handle.availableData) }
            stderr.fileHandleForReading.readabilityHandler = { handle in append(handle.availableData) }

            process.terminationHandler = { [weak self] process in
                stdout.fileHandleForReading.readabilityHandler = nil
                stderr.fileHandleForReading.readabilityHandler = nil
                do {
                    guard var current = try self?.registry.get(id: recordID), current.pids.contains(process.processIdentifier) else { return }
                    current.pids.removeAll { $0 == process.processIdentifier }
                    current.pid = current.pids.first
                    if current.pids.isEmpty {
                        current.status = process.terminationStatus == 0 ? .stopped : .failed
                    }
                    _ = try self?.registry.update(current)
                    self?.lock.withLock {
                        self?.running[recordID]?.removeAll { $0.process.processIdentifier == process.processIdentifier }
                        if self?.running[recordID]?.isEmpty == true {
                            _ = self?.running.removeValue(forKey: recordID)
                        }
                    }
                } catch {
                    Self.append(data: Data("\n[launcher] failed to update termination status: \(error)\n".utf8), to: outputURL)
                }
            }

            try process.run()
            started.append(RunningProcess(process: process, stdout: stdout, stderr: stderr))
            startedPids.append(process.processIdentifier)
        }

        lock.withLock { running[recordID] = started }
        record.pids = startedPids
        record.pid = startedPids.first
        record.status = .running
        return try registry.update(record)
    }

    public func stop(id: String) throws -> AppRecord {
        guard var record = try registry.get(id: id) else { throw AppRegistry.RegistryError.notFound(id) }
        let pids = Set(record.pids + (record.pid.map { [$0] } ?? []))
        for pid in pids where ProcessTree.isRunning(pid: pid) {
            ProcessTree.terminateTree(pid: pid)
        }
        lock.withLock { _ = running.removeValue(forKey: record.id) }
        record.pid = nil
        record.pids = []
        record.status = .stopped
        return try registry.update(record)
    }

    public func restart(id: String) throws -> AppRecord {
        _ = try stop(id: id)
        return try start(id: id)
    }

    public func refreshStatuses() throws -> [AppRecord] {
        var refreshed: [AppRecord] = []
        for var record in try registry.list() {
            let originalPids = record.pids
            let livePids = originalPids.filter(ProcessTree.isRunning(pid:))
            if livePids != originalPids || (record.pid != nil && record.pid.map(ProcessTree.isRunning(pid:)) == false) {
                record.pids = livePids
                record.pid = livePids.first
                record.status = livePids.isEmpty ? .stale : .running
                record = try registry.update(record)
            }
            refreshed.append(record)
        }
        return refreshed
    }

    private static func append(data: Data, to url: URL) {
        do {
            let handle = try FileHandle(forWritingTo: url)
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            try handle.close()
        } catch {
            try? data.write(to: url)
        }
    }
}
