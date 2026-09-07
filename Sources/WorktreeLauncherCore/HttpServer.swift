import Foundation
import Network

public final class HttpServer: @unchecked Sendable {
    public let port: UInt16
    private let router: JsonRouter
    private var listener: NWListener?

    public init(port: UInt16 = 17_678, router: JsonRouter) {
        self.port = port
        self.router = router
    }

    public func start() throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(IPv4Address("127.0.0.1")!), port: NWEndpoint.Port(rawValue: port)!)
        let listener = try NWListener(using: parameters)
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
        listener.start(queue: .global(qos: .userInitiated))
        self.listener = listener
    }

    public func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        receive(on: connection, buffer: Data())
    }

    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            guard let self else { connection.cancel(); return }
            var nextBuffer = buffer
            if let data { nextBuffer.append(data) }
            if let request = Self.parse(data: nextBuffer) {
                self.respond(to: request, on: connection)
                return
            }
            if isComplete || error != nil {
                self.send(HttpResponse(status: 400, body: Data(#"{"error":"bad request"}"#.utf8)), on: connection)
                return
            }
            self.receive(on: connection, buffer: nextBuffer)
        }
    }

    private func respond(to request: HttpRequest, on connection: NWConnection) {
        let response: HttpResponse
        do {
            response = try router.handle(request)
        } catch {
            response = HttpResponse(status: 500, body: Data("{\"error\":\"\(String(describing: error))\"}".utf8))
        }
        send(response, on: connection)
    }

    private func send(_ response: HttpResponse, on connection: NWConnection) {
        let reason = Self.reason(for: response.status)
        var header = "HTTP/1.1 \(response.status) \(reason)\r\nContent-Length: \(response.body.count)\r\nConnection: close\r\n"
        for (key, value) in response.headers {
            header += "\(key): \(value)\r\n"
        }
        header += "\r\n"
        var data = Data(header.utf8)
        data.append(response.body)
        connection.send(content: data, completion: .contentProcessed { _ in connection.cancel() })
    }

    private static func parse(data: Data) -> HttpRequest? {
        let delimiter = Data("\r\n\r\n".utf8)
        guard let headerRange = data.range(of: delimiter), let headerText = String(data: data[..<headerRange.lowerBound], encoding: .utf8) else { return nil }
        let lines = headerText.split(separator: "\r\n", omittingEmptySubsequences: false).map(String.init)
        guard let requestLine = lines.first else { return nil }
        let requestParts = requestLine.split(separator: " ").map(String.init)
        guard requestParts.count >= 2 else { return nil }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespacesAndNewlines)
            headers[key] = value
        }

        let contentLength = Int(headers["content-length"] ?? "0") ?? 0
        let bodyStart = headerRange.upperBound
        guard data.count >= bodyStart + contentLength else { return nil }
        let body = contentLength == 0 ? Data() : data.subdata(in: bodyStart..<(bodyStart + contentLength))
        return HttpRequest(method: requestParts[0], path: requestParts[1], headers: headers, body: body)
    }

    private static func reason(for status: Int) -> String {
        switch status {
        case 200: "OK"
        case 201: "Created"
        case 204: "No Content"
        case 400: "Bad Request"
        case 401: "Unauthorized"
        case 404: "Not Found"
        default: "Internal Server Error"
        }
    }
}
