import Darwin
import Foundation

public enum ProcessTree {
    public static func isRunning(pid: Int32) -> Bool {
        guard pid > 0 else { return false }
        return kill(pid, 0) == 0
    }

    public static func descendants(of pid: Int32) -> [Int32] {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,ppid="]
        process.standardOutput = pipe
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        var childrenByParent: [Int32: [Int32]] = [:]
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: " ").compactMap { Int32($0.trimmingCharacters(in: .whitespaces)) }
            guard parts.count == 2 else { continue }
            childrenByParent[parts[1], default: []].append(parts[0])
        }

        var result: [Int32] = []
        var stack = childrenByParent[pid] ?? []
        while let child = stack.popLast() {
            result.append(child)
            stack.append(contentsOf: childrenByParent[child] ?? [])
        }
        return result
    }

    public static func terminateTree(pid: Int32, graceSeconds: TimeInterval = 2.0) {
        guard pid > 0 else { return }
        Darwin.kill(-pid, SIGTERM)
        let targets = descendants(of: pid).reversed() + [pid]
        for target in targets {
            Darwin.kill(target, SIGTERM)
        }

        let deadline = Date().addingTimeInterval(graceSeconds)
        while Date() < deadline {
            if !isRunning(pid: pid) { return }
            Thread.sleep(forTimeInterval: 0.05)
        }

        Darwin.kill(-pid, SIGKILL)
        let remaining = descendants(of: pid).reversed() + [pid]
        for target in remaining where isRunning(pid: target) {
            Darwin.kill(target, SIGKILL)
        }
    }
}
