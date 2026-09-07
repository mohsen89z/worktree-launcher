import Foundation

public struct LogStore: Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public func logURL(for id: String) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("\(id).log")
    }

    public func tail(id: String, lines: Int) throws -> String {
        let url = try logURL(for: id)
        guard FileManager.default.fileExists(atPath: url.path) else { return "" }
        let text = try String(contentsOf: url, encoding: .utf8)
        return text.split(separator: "\n", omittingEmptySubsequences: true).suffix(max(0, lines)).joined(separator: "\n")
    }
}
