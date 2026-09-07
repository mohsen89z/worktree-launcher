import Foundation
import WorktreeLauncherCLI

@main
struct WtLaunchMain {
    static func main() async {
        let command: LaunchCommand
        do {
            command = try LaunchArgumentParser.parse(Array(CommandLine.arguments.dropFirst()))
        } catch {
            // No command, or a malformed one: usage belongs on stderr with a non-zero exit.
            fputs("wt-launch: \(error)\n\n\(LaunchUsage.text)\n", stderr)
            Foundation.exit(1)
        }

        if case .help = command {
            print(LaunchUsage.text)
            return
        }

        do {
            let token = try LaunchClient.loadDefaultToken()
            let output = try await LaunchClient(token: token).run(command)
            if !output.isEmpty {
                print(output)
            }
        } catch {
            fputs("wt-launch: \(error)\n", stderr)
            Foundation.exit(1)
        }
    }
}
