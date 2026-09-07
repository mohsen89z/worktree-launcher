import Foundation

public struct HttpRequest: Sendable {
    public var method: String
    public var path: String
    public var headers: [String: String]
    public var body: Data

    public init(method: String, path: String, headers: [String: String], body: Data) {
        self.method = method.uppercased()
        self.path = path
        self.headers = Dictionary(uniqueKeysWithValues: headers.map { ($0.key.lowercased(), $0.value) })
        self.body = body
    }
}

public struct HttpResponse: Sendable {
    public var status: Int
    public var headers: [String: String]
    public var body: Data

    public init(status: Int, headers: [String: String] = ["Content-Type": "application/json"], body: Data = Data()) {
        self.status = status
        self.headers = headers
        self.body = body
    }
}

public final class JsonRouter: @unchecked Sendable {
    private let registry: AppRegistry
    private let processManager: ProcessManager
    private let logStore: LogStore
    private let token: String

    public init(registry: AppRegistry, processManager: ProcessManager, logStore: LogStore, token: String) {
        self.registry = registry
        self.processManager = processManager
        self.logStore = logStore
        self.token = token
    }

    public func handle(_ request: HttpRequest) throws -> HttpResponse {
        do {
            return try route(request)
        } catch let error as PortGuard.PortError {
            return self.error(error.description, status: 409)
        }
    }

    private func route(_ request: HttpRequest) throws -> HttpResponse {
        let parsed = ParsedPath(request.path)
        if request.method == "GET", parsed.path == "/health" {
            return try json(HealthResponse(ok: true, version: "0.1.0"), status: 200)
        }
        guard isAuthorized(request) else { return error("unauthorized", status: 401) }

        if request.method == "GET", parsed.path == "/apps" {
            return try json(registry.list(), status: 200)
        }

        if request.method == "POST", parsed.path == "/apps" {
            let registration = try JSONDecoder.launcher.decode(RegisterAppRequest.self, from: request.body)
            let record = try registry.register(registration)
            let output = registration.start ? try processManager.start(id: record.id) : record
            return try json(output, status: 201)
        }

        let components = parsed.path.split(separator: "/").map(String.init)
        if components.count >= 2, components[0] == "apps" {
            let id = components[1]
            if components.count == 3, components[2] == "logs", request.method == "GET" {
                let lines = Int(parsed.query["lines"] ?? "200") ?? 200
                guard let record = try registry.get(id: id) else { return error("not found", status: 404) }
                let text = try logStore.tail(id: record.id, lines: lines)
                return HttpResponse(status: 200, headers: ["Content-Type": "text/plain; charset=utf-8"], body: Data(text.utf8))
            }
            if components.count == 3, components[2] == "start", request.method == "POST" {
                return try json(processManager.start(id: id), status: 200)
            }
            if components.count == 3, components[2] == "stop", request.method == "POST" {
                return try json(processManager.stop(id: id), status: 200)
            }
            if components.count == 3, components[2] == "restart", request.method == "POST" {
                return try json(processManager.restart(id: id), status: 200)
            }
            if components.count == 2, request.method == "DELETE" {
                try registry.remove(id: id)
                return HttpResponse(status: 204, headers: [:], body: Data())
            }
        }

        return error("not found", status: 404)
    }

    private func isAuthorized(_ request: HttpRequest) -> Bool {
        request.headers["authorization"] == "Bearer \(token)"
    }

    private func json<T: Encodable>(_ value: T, status: Int) throws -> HttpResponse {
        try HttpResponse(status: status, body: JSONEncoder.launcher.encode(value))
    }

    private func error(_ message: String, status: Int) -> HttpResponse {
        let data = (try? JSONEncoder.launcher.encode(["error": message])) ?? Data()
        return HttpResponse(status: status, body: data)
    }

    private struct HealthResponse: Encodable {
        let ok: Bool
        let version: String
    }

    private struct ParsedPath {
        let path: String
        let query: [String: String]

        init(_ raw: String) {
            let parts = raw.split(separator: "?", maxSplits: 1).map(String.init)
            path = parts.first ?? raw
            if parts.count == 2 {
                query = Dictionary(uniqueKeysWithValues: parts[1].split(separator: "&").compactMap { item in
                    let pair = item.split(separator: "=", maxSplits: 1).map(String.init)
                    guard pair.count == 2 else { return nil }

                    return (pair[0], pair[1].removingPercentEncoding ?? pair[1])
                })
            } else {
                query = [:]
            }
        }
    }
}
