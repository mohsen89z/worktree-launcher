import Foundation

public enum CommandValidation {
    public enum ValidationError: Error, Equatable, CustomStringConvertible {
        case blankName
        case blankCommand
        case missingWorkingDirectory
        case invalidPort(Int)

        public var description: String {
            switch self {
            case .blankName:
                "name is required"
            case .blankCommand:
                "command is required"
            case .missingWorkingDirectory:
                "cwd does not exist"
            case .invalidPort(let port):
                "invalid port: \(port)"
            }
        }
    }

    public static func validateRegistration(_ request: RegisterAppRequest) throws {
        if request.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ValidationError.blankName
        }
        if request.commands.isEmpty || request.commands.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            throw ValidationError.blankCommand
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: request.cwd, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw ValidationError.missingWorkingDirectory
        }
        for port in request.ports where port < 1 || port > 65_535 {
            throw ValidationError.invalidPort(port)
        }
    }
}
