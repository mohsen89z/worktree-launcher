import Darwin
import Foundation
import Testing
@testable import WorktreeLauncherCore

@Suite("Port guard", .serialized)
struct PortGuardTests {
    @Test("detects a listening port as unavailable")
    func detectsListeningPortAsUnavailable() throws {
        let listener = try TestListener()
        #expect(PortGuard.isPortInUse(listener.port))
        listener.close()
        #expect(!PortGuard.isPortInUse(listener.port))
    }

    @Test("rejects registration when another record already claims the port")
    func rejectsRegistrationWhenPortAlreadyClaimed() throws {
        let root = try temporaryDirectory()
        let registry = try AppRegistry(storageURL: root.appendingPathComponent("registry.json"), logsDirectory: root.appendingPathComponent("logs"))
        let port = try freePort()
        _ = try registry.register(RegisterAppRequest(name: "web-app", cwd: root.path, command: "sleep 1", url: nil, ports: [port], tags: [], start: false))

        do {
            _ = try registry.register(RegisterAppRequest(name: "api", cwd: root.path, command: "sleep 1", url: nil, ports: [port], tags: [], start: false))
            Issue.record("Expected port conflict error")
        } catch let error as PortGuard.PortError {
            guard case let .registered(conflicting, owner, suggestion) = error else {
                Issue.record("Expected registered conflict, got \(error)")
                return
            }
            #expect(conflicting == port)
            #expect(owner.contains("web-app"))
            #expect(suggestion != port)
            #expect(error.description.contains("choose another port"))
        }
    }

    @Test("rejects registration when the port is already bound by another process")
    func rejectsRegistrationWhenPortAlreadyBound() throws {
        let root = try temporaryDirectory()
        let registry = try AppRegistry(storageURL: root.appendingPathComponent("registry.json"), logsDirectory: root.appendingPathComponent("logs"))
        let listener = try TestListener()
        defer { listener.close() }

        do {
            _ = try registry.register(RegisterAppRequest(name: "web-app", cwd: root.path, command: "sleep 1", url: nil, ports: [listener.port], tags: [], start: false))
            Issue.record("Expected port in-use error")
        } catch let error as PortGuard.PortError {
            guard case let .inUse(conflicting, suggestion) = error else {
                Issue.record("Expected in-use conflict, got \(error)")
                return
            }
            #expect(conflicting == listener.port)
            #expect(suggestion != listener.port)
            #expect(error.description.contains("choose another port"))
        }
    }

    private func freePort() throws -> Int {
        let listener = try TestListener()
        let port = listener.port
        listener.close()
        return port
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

private final class TestListener {
    let port: Int
    private let descriptor: Int32
    private var closed = false

    init() throws {
        let handle = socket(AF_INET, SOCK_STREAM, 0)
        guard handle >= 0 else { throw TestListenerError.socketFailed }
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = 0
        address.sin_addr = in_addr(s_addr: INADDR_ANY)
        let bound = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.bind(handle, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        guard bound == 0, Darwin.listen(handle, 1) == 0 else {
            Darwin.close(handle)
            throw TestListenerError.bindFailed
        }
        var assigned = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let named = withUnsafeMutablePointer(to: &assigned) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(handle, $0, &length) }
        }
        guard named == 0 else {
            Darwin.close(handle)
            throw TestListenerError.bindFailed
        }
        descriptor = handle
        port = Int(UInt16(bigEndian: assigned.sin_port))
    }

    func close() {
        guard !closed else { return }
        closed = true
        Darwin.close(descriptor)
    }

    enum TestListenerError: Error {
        case socketFailed
        case bindFailed
    }
}
