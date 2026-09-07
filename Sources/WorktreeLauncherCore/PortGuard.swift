import Darwin
import Foundation

public enum PortGuard {
    public enum PortError: Error, Equatable, CustomStringConvertible {
        case registered(port: Int, owner: String, suggestion: Int?)
        case inUse(port: Int, suggestion: Int?)

        public var description: String {
            switch self {
            case .registered(let port, let owner, let suggestion):
                "port \(port) is already allocated to \(owner); choose another port\(Self.hint(suggestion))"
            case .inUse(let port, let suggestion):
                "port \(port) is already in use by another process; choose another port\(Self.hint(suggestion))"
            }
        }

        private static func hint(_ suggestion: Int?) -> String {
            suggestion.map { " (\($0) is free)" } ?? ""
        }
    }

    /// True when something is currently accepting TCP connections on the port.
    public static func isPortInUse(_ port: Int) -> Bool {
        guard port > 0, port <= 65_535 else { return false }
        return canConnect(port: port, family: AF_INET) || canConnect(port: port, family: AF_INET6)
    }

    /// First port that is still occupied, retrying until `timeout` elapses.
    public static func firstUnavailable(in ports: [Int], waitingUpTo timeout: TimeInterval = 0) -> Int? {
        guard !ports.isEmpty else { return nil }
        let deadline = Date().addingTimeInterval(timeout)
        while true {
            guard let busy = ports.first(where: isPortInUse) else { return nil }
            if Date() >= deadline { return busy }
            Thread.sleep(forTimeInterval: 0.1)
        }
    }

    /// Nearest higher port that is neither claimed by a record nor bound by a process.
    public static func suggestPort(near port: Int, claimed: Set<Int>, span: Int = 200) -> Int? {
        guard port > 0 else { return nil }
        for candidate in (port + 1)...(min(port + span, 65_535)) where !claimed.contains(candidate) && !isPortInUse(candidate) {
            return candidate
        }
        return nil
    }

    private static func canConnect(port: Int, family: Int32) -> Bool {
        let descriptor = socket(family, SOCK_STREAM, 0)
        guard descriptor >= 0 else { return false }
        defer { Darwin.close(descriptor) }

        var timeout = timeval(tv_sec: 0, tv_usec: 200_000)
        setsockopt(descriptor, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        if family == AF_INET {
            var address = sockaddr_in()
            address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            address.sin_family = sa_family_t(AF_INET)
            address.sin_port = UInt16(port).bigEndian
            address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
            return withUnsafePointer(to: &address) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) == 0
                }
            }
        }

        var address = sockaddr_in6()
        address.sin6_len = UInt8(MemoryLayout<sockaddr_in6>.size)
        address.sin6_family = sa_family_t(AF_INET6)
        address.sin6_port = UInt16(port).bigEndian
        address.sin6_addr = in6addr_loopback
        return withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in6>.size)) == 0
            }
        }
    }
}
