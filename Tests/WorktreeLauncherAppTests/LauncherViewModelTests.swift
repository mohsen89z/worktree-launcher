import Foundation
import Testing
@testable import WorktreeLauncherAppSupport
@testable import WorktreeLauncherCore

@Suite("Launcher view model")
struct LauncherViewModelTests {
    @Test("restart calls process control and reloads records")
    func restartCallsProcessControlAndReloadsRecords() async throws {
        let fake = FakeController()
        let record = AppRecord(id: "web-app-1", name: "web-app", cwd: "/tmp", command: "npm run dev", url: nil, ports: [], tags: [], pid: nil, status: .stopped, logPath: "/tmp/log", createdAt: Date(), updatedAt: Date())
        fake.records = [record]
        let viewModel = await LauncherViewModel(controller: fake)

        await viewModel.restart(recordID: "web-app-1")

        #expect(fake.restartCalls == ["web-app-1"])
        let records = await viewModel.records
        #expect(records.map(\.id) == ["web-app-1"])
    }

    @Test("auto refresh keeps polling until it is stopped")
    func autoRefreshPollsUntilStopped() async throws {
        let fake = FakeController()
        fake.records = [AppRecord(id: "web-app-1", name: "web-app", cwd: "/tmp", command: "npm run dev", url: nil, ports: [], tags: [], pid: nil, status: .stopped, logPath: "/tmp/log", createdAt: Date(), updatedAt: Date())]
        let viewModel = await LauncherViewModel(controller: fake)
        let baseline = fake.refreshCalls

        await viewModel.startAutoRefresh(every: 0.05)
        let deadline = Date().addingTimeInterval(3)
        while fake.refreshCalls < baseline + 3, Date() < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(fake.refreshCalls >= baseline + 3)

        await viewModel.stopAutoRefresh()
        try await Task.sleep(for: .milliseconds(100))
        let settled = fake.refreshCalls
        try await Task.sleep(for: .milliseconds(250))
        #expect(fake.refreshCalls == settled)
    }
}

private final class FakeController: LauncherControlling, @unchecked Sendable {
    var records: [AppRecord] = []
    var restartCalls: [String] = []

    var refreshCalls = 0

    func refresh() throws -> [AppRecord] {
        refreshCalls += 1
        return records
    }
    func start(recordID: String) throws -> AppRecord { records[0] }
    func stop(recordID: String) throws -> AppRecord { records[0] }
    func restart(recordID: String) throws -> AppRecord {
        restartCalls.append(recordID)
        return records[0]
    }
    func remove(recordID: String) throws {}
    func logs(recordID: String, lines: Int) throws -> String { "" }
}
