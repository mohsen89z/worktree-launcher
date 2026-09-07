import Foundation

public struct WebApplication: Codable, Equatable, Identifiable, Sendable {
    public var id: String { label }
    public var label: String
    public var url: String

    public init(label: String, url: String) {
        self.label = label
        self.url = url
    }
}

public struct RegisterAppRequest: Codable, Equatable, Sendable {
    public var name: String
    public var cwd: String
    public var command: String
    public var commands: [String]
    public var url: String?
    public var webApplications: [WebApplication]
    public var ports: [Int]
    public var tags: [String]
    public var start: Bool

    public init(name: String, cwd: String, command: String, commands: [String]? = nil, url: String?, webApplications: [WebApplication] = [], ports: [Int], tags: [String], start: Bool) {
        self.name = name
        self.cwd = cwd
        self.command = command
        self.commands = commands ?? [command]
        self.url = url
        self.webApplications = webApplications
        self.ports = ports
        self.tags = tags
        self.start = start
    }
}

public struct AppRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var cwd: String
    public var command: String
    public var commands: [String]
    public var url: String?
    public var webApplications: [WebApplication]
    public var ports: [Int]
    public var tags: [String]
    public var pid: Int32?
    public var pids: [Int32]
    public var status: AppRuntimeStatus
    public var logPath: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: String, name: String, cwd: String, command: String, commands: [String]? = nil, url: String?, webApplications: [WebApplication] = [], ports: [Int], tags: [String], pid: Int32?, pids: [Int32]? = nil, status: AppRuntimeStatus, logPath: String, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.name = name
        self.cwd = cwd
        self.command = command
        self.commands = commands ?? [command]
        self.url = url
        self.webApplications = webApplications
        self.ports = ports
        self.tags = tags
        self.pid = pid
        self.pids = pids ?? pid.map { [$0] } ?? []
        self.status = status
        self.logPath = logPath
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, cwd, command, commands, url, webApplications, ports, tags, pid, pids, status, logPath, createdAt, updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        cwd = try container.decode(String.self, forKey: .cwd)
        command = try container.decodeIfPresent(String.self, forKey: .command) ?? ""
        commands = try container.decodeIfPresent([String].self, forKey: .commands) ?? (command.isEmpty ? [] : [command])
        if command.isEmpty, let first = commands.first {
            command = first
        }
        url = try container.decodeIfPresent(String.self, forKey: .url)
        webApplications = try container.decodeIfPresent([WebApplication].self, forKey: .webApplications) ?? []
        if webApplications.isEmpty, let url {
            webApplications = [WebApplication(label: name, url: url)]
        }
        ports = try container.decode([Int].self, forKey: .ports)
        tags = try container.decode([String].self, forKey: .tags)
        pid = try container.decodeIfPresent(Int32.self, forKey: .pid)
        pids = try container.decodeIfPresent([Int32].self, forKey: .pids) ?? pid.map { [$0] } ?? []
        status = try container.decode(AppRuntimeStatus.self, forKey: .status)
        logPath = try container.decode(String.self, forKey: .logPath)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}
