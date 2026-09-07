import Foundation
import OSLog
import WorktreeLauncherCore

public protocol LauncherControlling: AnyObject, Sendable {
    func refresh() throws -> [AppRecord]
    func start(recordID: String) throws -> AppRecord
    func stop(recordID: String) throws -> AppRecord
    func restart(recordID: String) throws -> AppRecord
    func remove(recordID: String) throws
    func logs(recordID: String, lines: Int) throws -> String
}

public final class DefaultLauncherController: LauncherControlling, @unchecked Sendable {
    private let registry: AppRegistry
    private let processManager: ProcessManager
    private let logStore: LogStore

    public init(registry: AppRegistry, processManager: ProcessManager, logStore: LogStore) {
        self.registry = registry
        self.processManager = processManager
        self.logStore = logStore
    }

    public func refresh() throws -> [AppRecord] {
        try processManager.refreshStatuses()
    }

    public func start(recordID: String) throws -> AppRecord {
        try processManager.start(id: recordID)
    }

    public func stop(recordID: String) throws -> AppRecord {
        try processManager.stop(id: recordID)
    }

    public func restart(recordID: String) throws -> AppRecord {
        try processManager.restart(id: recordID)
    }

    public func remove(recordID: String) throws {
        try registry.remove(id: recordID)
    }

    public func logs(recordID: String, lines: Int) throws -> String {
        guard let record = try registry.get(id: recordID) else { throw AppRegistry.RegistryError.notFound(recordID) }
        return try logStore.tail(id: record.id, lines: lines)
    }
}

@MainActor
public final class LauncherViewModel: ObservableObject {
    @Published public private(set) var records: [AppRecord] = []
    @Published public var errorMessage: String?
    @Published public var logPreview: String = ""

    private let controller: LauncherControlling
    private var autoRefreshTask: Task<Void, Never>?

    public init(controller: LauncherControlling) {
        self.controller = controller
        refresh()
    }

    /// Polls for the app's lifetime so records, PIDs, and status dots stay current without a manual refresh.
    public func startAutoRefresh(every interval: TimeInterval = 15) {
        stopAutoRefresh()
        autoRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled, let self else { return }
                self.refresh()
                Self.log.notice("panel auto-refresh tick: \(self.records.count, privacy: .public) records")
            }
        }
    }

    public func stopAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
    }

    static let log = Logger(subsystem: "io.github.mohsen89z.worktree-launcher", category: "panel")

    public func refresh() {
        do {
            records = try controller.refresh()
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }

    public func start(recordID: String) {
        perform { try controller.start(recordID: recordID) }
    }

    public func stop(recordID: String) {
        perform { try controller.stop(recordID: recordID) }
    }

    public func restart(recordID: String) {
        perform { try controller.restart(recordID: recordID) }
    }

    public func remove(recordID: String) {
        do {
            try controller.remove(recordID: recordID)
            refresh()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    public func showLogs(recordID: String) {
        do {
            logPreview = try controller.logs(recordID: recordID, lines: 80)
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func perform(_ action: () throws -> AppRecord) {
        do {
            _ = try action()
            refresh()
        } catch {
            errorMessage = String(describing: error)
        }
    }
}
