import AppKit
import WorktreeLauncherAppSupport
import WorktreeLauncherCore

@MainActor
final class LauncherAppDelegate: NSObject, NSApplicationDelegate {
    private var viewModel: LauncherViewModel?
    private var loginItemController: LoginItemController?
    private var server: HttpServer?
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        ProcessInfo.processInfo.disableAutomaticTermination("Worktree Launcher owns long-running dev processes")

        do {
            let registry = try AppRegistry(storageURL: AppRegistry.defaultStorageURL(), logsDirectory: AppRegistry.defaultLogsDirectory())
            let processManager = ProcessManager(registry: registry)
            let logStore = LogStore(directory: AppRegistry.defaultLogsDirectory())
            let token = try AuthTokenStore(tokenURL: AuthTokenStore.defaultTokenURL()).loadOrCreateToken()
            let router = JsonRouter(registry: registry, processManager: processManager, logStore: logStore, token: token)
            let server = HttpServer(router: router)
            let controller = DefaultLauncherController(registry: registry, processManager: processManager, logStore: logStore)
            let viewModel = LauncherViewModel(controller: controller)
            let loginItemController = LoginItemController()

            try server.start()
            loginItemController.ensureEnabled()

            self.server = server
            self.viewModel = viewModel
            self.loginItemController = loginItemController
            statusItemController = StatusItemController(viewModel: viewModel, loginItemController: loginItemController)
            viewModel.startAutoRefresh(every: StatusItemController.refreshInterval)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Worktree Launcher failed to start"
            alert.informativeText = String(describing: error)
            alert.runModal()
            NSApplication.shared.terminate(nil)
            return
        }

        if !CommandLine.arguments.contains("--background") {
            statusItemController?.showPopover()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusItemController?.showPopover()
        return true
    }
}

let delegate = LauncherAppDelegate()
let application = NSApplication.shared
application.delegate = delegate
// Menu bar only: no Dock icon, no phantom window competing for activation.
application.setActivationPolicy(.accessory)
application.run()
