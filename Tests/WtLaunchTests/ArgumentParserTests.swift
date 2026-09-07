import Testing
@testable import WorktreeLauncherCLI

@Suite("wt-launch argument parser")
struct ArgumentParserTests {
    @Test("parses register command")
    func parsesRegisterCommand() throws {
        let command = try LaunchArgumentParser.parse(["register", "--name", "web-app", "--cwd", "/tmp", "--command", "npm run dev", "--url", "http://localhost:3000", "--port", "3000", "--tag", "frontend", "--start"])
        guard case let .register(request) = command else {
            Issue.record("Expected register command")
            return
        }
        #expect(request.name == "web-app")
        #expect(request.cwd == "/tmp")
        #expect(request.command == "npm run dev")
        #expect(request.url == "http://localhost:3000")
        #expect(request.ports == [3000])
        #expect(request.tags == ["frontend"])
        #expect(request.start)
    }

    @Test("parses multiservice register command")
    func parsesMultiserviceRegisterCommand() throws {
        let command = try LaunchArgumentParser.parse([
            "register",
            "--name", "local-stack",
            "--cwd", "/tmp",
            "--command", "npm run dev:web",
            "--command", "npm run dev:api",
            "--web-app", "Web=http://localhost:3000",
            "--web-app", "API=http://localhost:4000",
            "--port", "3000",
            "--port", "4000",
            "--start",
        ])
        guard case let .register(request) = command else {
            Issue.record("Expected register command")
            return
        }
        #expect(request.commands == ["npm run dev:web", "npm run dev:api"])
        #expect(request.webApplications.map(\.label) == ["Web", "API"])
        #expect(request.webApplications.map(\.url) == ["http://localhost:3000", "http://localhost:4000"])
        #expect(request.ports == [3000, 4000])
    }

    @Test("recognises every help spelling, including after a subcommand")
    func recognisesHelpFlags() throws {
        #expect(try LaunchArgumentParser.parse(["--help"]) == .help)
        #expect(try LaunchArgumentParser.parse(["-h"]) == .help)
        #expect(try LaunchArgumentParser.parse(["help"]) == .help)
        #expect(try LaunchArgumentParser.parse(["register", "--help"]) == .help)
        #expect(try LaunchArgumentParser.parse(["logs", "web-app", "-h"]) == .help)
    }

    @Test("usage text documents every command and the flags agents need")
    func usageDocumentsEveryCommand() {
        let usage = LaunchUsage.text
        for command in ["register", "list", "start", "stop", "restart", "open", "logs", "remove"] {
            #expect(usage.contains(command))
        }
        for flag in ["--name", "--cwd", "--command", "--web-app", "--port", "--tag", "--start", "--lines"] {
            #expect(usage.contains(flag))
        }
        #expect(usage.contains("list --cwd"))
    }

    @Test("parses list scoped to a worktree")
    func parsesListScopedToWorktree() throws {
        #expect(try LaunchArgumentParser.parse(["list"]) == .list(cwd: nil))
        #expect(try LaunchArgumentParser.parse(["list", "--cwd", "/tmp/wt"]) == .list(cwd: "/tmp/wt"))
    }

    @Test("parses restart command")
    func parsesRestartCommand() throws {
        #expect(try LaunchArgumentParser.parse(["restart", "web-app"]) == .restart("web-app"))
    }

    @Test("parses logs command")
    func parsesLogsCommand() throws {
        #expect(try LaunchArgumentParser.parse(["logs", "web-app", "--lines", "100"]) == .logs("web-app", lines: 100))
    }

    @Test("rejects register missing command")
    func rejectsRegisterMissingCommand() throws {
        do {
            _ = try LaunchArgumentParser.parse(["register", "--name", "web-app", "--cwd", "/tmp"])
            Issue.record("Expected missing option error")
        } catch let error as LaunchArgumentParser.ParseError {
            #expect(error == .missingOption("--command"))
        }
    }
}
