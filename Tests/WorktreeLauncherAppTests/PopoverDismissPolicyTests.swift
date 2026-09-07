import Testing
@testable import WorktreeLauncherAppSupport

@Suite("Popover dismiss policy")
struct PopoverDismissPolicyTests {
    @Test("mouse movement never closes the panel")
    func mouseMovementNeverCloses() {
        #expect(!PopoverDismissPolicy.shouldClose(.mouseMoved))
        #expect(!PopoverDismissPolicy.shouldClose(.scrollWheel))
    }

    @Test("only outside clicks, escape, deactivation, and status item re-click close the panel")
    func onlyDeliberateActionsClose() {
        #expect(PopoverDismissPolicy.shouldClose(.mouseDown(insidePanel: false)))
        #expect(!PopoverDismissPolicy.shouldClose(.mouseDown(insidePanel: true)))
        #expect(PopoverDismissPolicy.shouldClose(.escapeKey))
        #expect(PopoverDismissPolicy.shouldClose(.statusItemClicked))
        #expect(PopoverDismissPolicy.shouldClose(.appResignedActive))
    }
}
