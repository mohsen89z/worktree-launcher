import AppKit
import SwiftUI
import WorktreeLauncherCore

@MainActor
public final class StatusItemController: NSObject, NSPopoverDelegate {
    /// How often the open panel re-reads the registry and process state.
    public static let refreshInterval: TimeInterval = 15

    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let viewModel: LauncherViewModel
    private var outsideClickMonitor: Any?
    private var localKeyMonitor: Any?
    private var resignObserver: NSObjectProtocol?

    public init(viewModel: LauncherViewModel, loginItemController: LoginItemController) {
        self.viewModel = viewModel
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: AppIcon.systemImage, accessibilityDescription: "Worktree Launcher")
            button.title = " \(AppIcon.menuBarTitle)"
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(statusItemClicked)
            button.toolTip = "Worktree Launcher"
        }

        // `.applicationDefined` keeps the panel open until a deliberate action closes it.
        // `.transient` dismissed the panel on the first stray event whenever the app was inactive.
        popover.behavior = .applicationDefined
        popover.animates = false
        popover.delegate = self
        popover.contentSize = NSSize(width: 460, height: 560)
        popover.contentViewController = NSHostingController(rootView: MenuBarView(viewModel: viewModel, loginItemController: loginItemController))
    }

    @objc private func statusItemClicked() {
        if popover.isShown, PopoverDismissPolicy.shouldClose(.statusItemClicked) {
            hidePopover()
        } else {
            showPopover()
        }
    }

    public func showPopover() {
        guard let button = statusItem.button else { return }
        NSApplication.shared.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        // Without key status the panel cannot take keyboard input and macOS treats it as background chrome.
        popover.contentViewController?.view.window?.makeKeyAndOrderFront(nil)
        // Instant freshness on open; the steady 15s poll runs for the app's lifetime.
        viewModel.refresh()
        installMonitors()
    }

    public func hidePopover() {
        removeMonitors()
        popover.performClose(nil)
    }

    public func popoverDidClose(_ notification: Notification) {
        removeMonitors()
    }

    private func installMonitors() {
        removeMonitors()

        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            guard let self, PopoverDismissPolicy.shouldClose(.mouseDown(insidePanel: false)) else { return }
            Task { @MainActor in self.hidePopover() }
        }

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self, event.keyCode == 53, PopoverDismissPolicy.shouldClose(.escapeKey) else { return event }
            self.hidePopover()
            return nil
        }

        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, PopoverDismissPolicy.shouldClose(.appResignedActive) else { return }
            Task { @MainActor in self.hidePopover() }
        }
    }

    private func removeMonitors() {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
            self.localKeyMonitor = nil
        }
        if let resignObserver {
            NotificationCenter.default.removeObserver(resignObserver)
            self.resignObserver = nil
        }
    }
}
