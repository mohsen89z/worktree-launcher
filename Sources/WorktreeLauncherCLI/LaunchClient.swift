import Foundation
import WorktreeLauncherCore

public final class LaunchClient {
    private let baseURL: URL
    private let token: String
    private let session: URLSession

    public init(baseURL: URL = URL(string: "http://127.0.0.1:17678")!, token: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.token = token
        self.session = session
    }

    public static func loadDefaultToken() throws -> String {
        try AuthTokenStore(tokenURL: AuthTokenStore.defaultTokenURL()).loadOrCreateToken()
    }

    public func run(_ command: LaunchCommand) async throws -> String {
        switch command {
        case .help:
            return LaunchUsage.text
        case .register(let request):
            let record: AppRecord = try await send("POST", path: "/apps", body: JSONEncoder.launcher.encode(request))
            return describe(record)
        case .list(let cwd):
            let records: [AppRecord] = try await send("GET", path: "/apps")
            let scoped = cwd.map { path in records.filter { $0.cwd == path } } ?? records
            if scoped.isEmpty {
                return cwd.map { "No registered apps for \($0) - register one" } ?? "No registered apps"
            }
            return scoped.map(describe).joined(separator: "\n")
        case .start(let id):
            let record: AppRecord = try await send("POST", path: "/apps/\(id)/start")
            return describe(record)
        case .stop(let id):
            let record: AppRecord = try await send("POST", path: "/apps/\(id)/stop")
            return describe(record)
        case .restart(let id):
            let record: AppRecord = try await send("POST", path: "/apps/\(id)/restart")
            return describe(record)
        case .open(let id):
            let records: [AppRecord] = try await send("GET", path: "/apps")
            guard let record = records.first(where: { $0.id == id || $0.name == id }), let webApp = record.webApplications.first ?? record.url.map({ WebApplication(label: record.name, url: $0) }) else {
                throw ClientError.missingURL(id)
            }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = [webApp.url]
            try process.run()
            return "Opened \(webApp.label) \(webApp.url)"
        case .logs(let id, let lines):
            let text: String = try await sendText("GET", path: "/apps/\(id)/logs?lines=\(lines)")
            return text
        case .remove(let id):
            try await sendEmpty("DELETE", path: "/apps/\(id)")
            return "Removed \(id)"
        }
    }

    private func send<T: Decodable>(_ method: String, path: String, body: Data = Data()) async throws -> T {
        let data = try await raw(method, path: path, body: body)
        return try JSONDecoder.launcher.decode(T.self, from: data)
    }

    private func sendText(_ method: String, path: String) async throws -> String {
        let data = try await raw(method, path: path, body: Data())
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func sendEmpty(_ method: String, path: String) async throws {
        _ = try await raw(method, path: path, body: Data())
    }

    private func raw(_ method: String, path: String, body: Data) async throws -> Data {
        var request = URLRequest(url: baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))))
        if path.contains("?") {
            request = URLRequest(url: URL(string: baseURL.absoluteString + path)!)
        }
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if !body.isEmpty {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ClientError.requestFailed(String(data: data, encoding: .utf8) ?? "request failed")
        }
        return data
    }

    private func describe(_ record: AppRecord) -> String {
        let pidText = record.pids.isEmpty ? (record.pid.map { "pids=\($0)" } ?? "pids=-") : "pids=\(record.pids.map(String.init).joined(separator: ","))"
        let urlText = record.webApplications.isEmpty ? (record.url ?? record.ports.first.map { "http://localhost:\($0)" } ?? "url=-") : record.webApplications.map { "\($0.label)=\($0.url)" }.joined(separator: ",")
        return "\(record.name) id=\(record.id) status=\(record.status.rawValue) \(pidText) \(urlText) cwd=\(record.cwd)"
    }

    public enum ClientError: Error, CustomStringConvertible {
        case requestFailed(String)
        case missingURL(String)

        public var description: String {
            switch self {
            case .requestFailed(let message): message
            case .missingURL(let id): "no URL registered for \(id)"
            }
        }
    }
}
