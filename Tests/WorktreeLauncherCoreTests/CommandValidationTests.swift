import Foundation
import Testing
@testable import WorktreeLauncherCore

@Suite("Command validation")
struct CommandValidationTests {
    @Test("accepts valid registration")
    func acceptsValidRegistration() throws {
        let request = RegisterAppRequest(
            name: "web-app",
            cwd: FileManager.default.currentDirectoryPath,
            command: "npm run dev",
            url: "http://localhost:3000",
            ports: [3000],
            tags: ["frontend"],
            start: true
        )

        try CommandValidation.validateRegistration(request)
    }

    @Test("rejects missing working directory")
    func rejectsMissingWorkingDirectory() throws {
        let request = RegisterAppRequest(
            name: "web-app",
            cwd: "/definitely/missing/worktree-launcher-test",
            command: "npm run dev",
            url: nil,
            ports: [],
            tags: [],
            start: false
        )

        do {
            try CommandValidation.validateRegistration(request)
            Issue.record("Expected missing working directory error")
        } catch let error as CommandValidation.ValidationError {
            #expect(error == .missingWorkingDirectory)
        }
    }

    @Test("rejects blank command")
    func rejectsBlankCommand() throws {
        let request = RegisterAppRequest(
            name: "web-app",
            cwd: FileManager.default.currentDirectoryPath,
            command: "   ",
            url: nil,
            ports: [],
            tags: [],
            start: false
        )

        do {
            try CommandValidation.validateRegistration(request)
            Issue.record("Expected blank command error")
        } catch let error as CommandValidation.ValidationError {
            #expect(error == .blankCommand)
        }
    }
}
