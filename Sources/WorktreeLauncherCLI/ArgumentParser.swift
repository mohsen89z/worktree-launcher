import Foundation
import WorktreeLauncherCore

public enum LaunchCommand: Equatable, Sendable {
    case register(RegisterAppRequest)
    case list(cwd: String?)
    case help
    case start(String)
    case stop(String)
    case restart(String)
    case open(String)
    case logs(String, lines: Int)
    case remove(String)
}

public enum LaunchArgumentParser {
    public enum ParseError: Error, Equatable, CustomStringConvertible {
        case missingCommand
        case unknownCommand(String)
        case missingIdentifier(String)
        case missingOption(String)
        case invalidPort(String)
        case invalidLines(String)
        case invalidWebApplication(String)

        public var description: String {
            switch self {
            case .missingCommand: "missing command"
            case .unknownCommand(let command): "unknown command: \(command)"
            case .missingIdentifier(let command): "\(command) requires a name or id"
            case .missingOption(let option): "missing option: \(option)"
            case .invalidPort(let value): "invalid port: \(value)"
            case .invalidLines(let value): "invalid lines: \(value)"
            case .invalidWebApplication(let value): "invalid web app: \(value)"
            }
        }
    }

    public static func parse(_ args: [String]) throws -> LaunchCommand {
        if args.contains("--help") || args.contains("-h") || args.first == "help" {
            return .help
        }
        guard let command = args.first else { throw ParseError.missingCommand }
        let rest = Array(args.dropFirst())
        switch command {
        case "register":
            return try .register(parseRegister(rest))
        case "list":
            return .list(cwd: try optionValue("--cwd", in: rest))
        case "start":
            return .start(try oneID(command: command, rest))
        case "stop":
            return .stop(try oneID(command: command, rest))
        case "restart":
            return .restart(try oneID(command: command, rest))
        case "open":
            return .open(try oneID(command: command, rest))
        case "logs":
            let id = try oneID(command: command, rest)
            let lines = try optionValue("--lines", in: rest).map { value in
                guard let parsed = Int(value), parsed > 0 else { throw ParseError.invalidLines(value) }
                return parsed
            } ?? 200
            return .logs(id, lines: lines)
        case "remove", "rm":
            return .remove(try oneID(command: command, rest))
        default:
            throw ParseError.unknownCommand(command)
        }
    }

    private static func parseRegister(_ args: [String]) throws -> RegisterAppRequest {
        let name = try required("--name", in: args)
        let cwd = try required("--cwd", in: args)
        var commands: [String] = []
        let url = try optionValue("--url", in: args)
        var webApplications: [WebApplication] = []
        var ports: [Int] = []
        var tags: [String] = []
        var index = 0
        while index < args.count {
            switch args[index] {
            case "--command":
                guard index + 1 < args.count else { throw ParseError.missingOption("--command") }
                commands.append(args[index + 1])
                index += 2
            case "--web-app":
                guard index + 1 < args.count else { throw ParseError.missingOption("--web-app") }
                webApplications.append(try parseWebApplication(args[index + 1]))
                index += 2
            case "--port":
                guard index + 1 < args.count else { throw ParseError.missingOption("--port") }
                guard let port = Int(args[index + 1]) else { throw ParseError.invalidPort(args[index + 1]) }
                ports.append(port)
                index += 2
            case "--tag":
                guard index + 1 < args.count else { throw ParseError.missingOption("--tag") }
                tags.append(args[index + 1])
                index += 2
            default:
                index += 1
            }
        }
        guard let command = commands.first else { throw ParseError.missingOption("--command") }
        return RegisterAppRequest(name: name, cwd: cwd, command: command, commands: commands, url: url, webApplications: webApplications, ports: ports, tags: tags, start: args.contains("--start"))
    }

    private static func oneID(command: String, _ args: [String]) throws -> String {
        guard let id = args.first, !id.hasPrefix("--") else { throw ParseError.missingIdentifier(command) }
        return id
    }

    private static func required(_ flag: String, in args: [String]) throws -> String {
        guard let value = try optionValue(flag, in: args), !value.isEmpty else { throw ParseError.missingOption(flag) }
        return value
    }

    private static func parseWebApplication(_ value: String) throws -> WebApplication {
        let parts = value.split(separator: "=", maxSplits: 1).map(String.init)
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else {
            throw ParseError.invalidWebApplication(value)
        }
        return WebApplication(label: parts[0], url: parts[1])
    }

    private static func optionValue(_ flag: String, in args: [String]) throws -> String? {
        guard let index = args.firstIndex(of: flag) else { return nil }
        guard index + 1 < args.count else { throw ParseError.missingOption(flag) }
        return args[index + 1]
    }
}
