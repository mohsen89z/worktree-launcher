import Testing
@testable import WorktreeLauncherAppSupport

@Suite("App icon")
struct AppIconTests {
    @Test("uses branded worktree identity instead of terminal")
    func usesBrandedWorktreeIdentity() {
        #expect(AppIcon.menuBarTitle == "WT")
        #expect(AppIcon.systemImage != "terminal")
    }
}
