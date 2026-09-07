import Foundation

/// What may dismiss the menu bar panel. Mouse movement must never close it.
public enum PopoverDismissTrigger: Equatable, Sendable {
    case mouseDown(insidePanel: Bool)
    case mouseMoved
    case scrollWheel
    case escapeKey
    case statusItemClicked
    case appResignedActive
}

public enum PopoverDismissPolicy {
    public static func shouldClose(_ trigger: PopoverDismissTrigger) -> Bool {
        switch trigger {
        case .mouseDown(let insidePanel): !insidePanel
        case .mouseMoved, .scrollWheel: false
        case .escapeKey, .statusItemClicked, .appResignedActive: true
        }
    }
}
