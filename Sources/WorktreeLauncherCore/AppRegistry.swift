import Foundation

public final class AppRegistry: @unchecked Sendable {
    private let storage: AtomicFileStore<[AppRecord]>
    private let logStore: LogStore
    private let lock = NSLock()
    private var records: [AppRecord]

    public init(storageURL: URL, logsDirectory: URL) throws {
        self.storage = AtomicFileStore<[AppRecord]>(url: storageURL)
        self.logStore = LogStore(directory: logsDirectory)
        self.records = try storage.load(default: [])
    }

    public static func defaultStorageURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Worktree Launcher", isDirectory: true)
            .appendingPathComponent("registry.json")
    }

    public static func defaultLogsDirectory() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Worktree Launcher", isDirectory: true)
    }

    public func list() throws -> [AppRecord] {
        lock.withLock { records.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending } }
    }

    public func get(id: String) throws -> AppRecord? {
        let resolved = try resolveID(id)
        guard let resolved else { return nil }
        return lock.withLock { records.first { $0.id == resolved } }
    }

    public func resolveID(_ nameOrID: String) throws -> String? {
        try lock.withLock {
            if records.contains(where: { $0.id == nameOrID }) {
                return nameOrID
            }
            let nameMatches = records.filter { $0.name == nameOrID }
            if nameMatches.count > 1 {
                throw RegistryError.ambiguousName(nameOrID)
            }
            return nameMatches.first?.id
        }
    }

    public func register(_ request: RegisterAppRequest) throws -> AppRecord {
        try CommandValidation.validateRegistration(request)
        try assertNotAlreadyRegistered(name: request.name, cwd: request.cwd)
        try assertPortsAvailable(request.ports, excluding: nil)
        let now = Date()
        let id = "\(Self.slug(request.name))-\(UUID().uuidString.prefix(8))"
        let logPath = try logStore.logURL(for: id).path
        let record = AppRecord(
            id: id,
            name: request.name,
            cwd: request.cwd,
            command: request.command,
            commands: request.commands,
            url: request.url,
            webApplications: request.webApplications,
            ports: request.ports,
            tags: request.tags,
            pid: nil,
            status: .stopped,
            logPath: logPath,
            createdAt: now,
            updatedAt: now
        )
        try mutate { records in
            records.append(record)
        }
        return record
    }

    /// A worktree gets one record per app. A second registration is an agent that forgot to look first.
    private func assertNotAlreadyRegistered(name: String, cwd: String) throws {
        let existing = lock.withLock {
            records.first { $0.name == name && $0.cwd == cwd }
        }
        if let existing {
            throw RegistryError.alreadyRegistered(id: existing.id, status: existing.status.rawValue)
        }
    }

    /// Rejects ports already claimed by another record or already bound by a running process.
    public func assertPortsAvailable(_ ports: [Int], excluding recordID: String?, waitingUpTo timeout: TimeInterval = 0) throws {
        guard !ports.isEmpty else { return }
        let (claimed, conflict) = lock.withLock { () -> (Set<Int>, (port: Int, owner: String)?) in
            let others = records.filter { $0.id != recordID }
            let claimed = Set(others.flatMap(\.ports))
            let conflict = others.lazy.compactMap { record -> (port: Int, owner: String)? in
                guard let port = ports.first(where: record.ports.contains) else { return nil }
                return (port, "\(record.name) (\(record.id))")
            }.first
            return (claimed, conflict)
        }
        if let conflict {
            throw PortGuard.PortError.registered(
                port: conflict.port,
                owner: conflict.owner,
                suggestion: PortGuard.suggestPort(near: conflict.port, claimed: claimed)
            )
        }
        if let busy = PortGuard.firstUnavailable(in: ports, waitingUpTo: timeout) {
            throw PortGuard.PortError.inUse(port: busy, suggestion: PortGuard.suggestPort(near: busy, claimed: claimed))
        }
    }

    public func update(_ record: AppRecord) throws -> AppRecord {
        var updated = record
        updated.updatedAt = Date()
        try mutate { records in
            guard let index = records.firstIndex(where: { $0.id == record.id }) else {
                throw RegistryError.notFound(record.id)
            }
            records[index] = updated
        }
        return updated
    }

    public func remove(id: String) throws {
        let resolved = try resolveID(id) ?? id
        try mutate { records in
            records.removeAll { $0.id == resolved }
        }
    }

    private func mutate(_ body: (inout [AppRecord]) throws -> Void) throws {
        try lock.withLock {
            try body(&records)
            try storage.save(records)
        }
    }

    private static func slug(_ text: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        let cleaned = text.lowercased().unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        let slug = String(cleaned).split(separator: "-").joined(separator: "-")
        return slug.isEmpty ? "app" : slug
    }

    public enum RegistryError: Error, Equatable, CustomStringConvertible {
        case notFound(String)
        case ambiguousName(String)
        case alreadyRegistered(id: String, status: String)

        public var description: String {
            switch self {
            case .notFound(let id):
                "record not found: \(id)"
            case .ambiguousName(let name):
                "multiple records named \(name); use the exact id"
            case .alreadyRegistered(let id, let status):
                "this app is already registered for this worktree as \(id) (status=\(status)); reuse it with `wt-launch restart \(id)` instead of registering a second one"
            }
        }
    }
}
