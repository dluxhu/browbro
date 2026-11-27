import AppKit

/// Finds out if a browser's last-used window is in the current Space.
/// It uses only the public window list and reads no window titles, so it needs
/// no Screen Recording or Accessibility permission and works in the App Sandbox.
enum SpaceWindows {
    /// True when the browser runs and its front window is not in the current
    /// Space. A plain open then puts the link in that window and macOS switches Space.
    static func frontWindowIsElsewhere(bundleID: String) -> Bool {
        let pids = Set(NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .map(\.processIdentifier))
        guard !pids.isEmpty else { return false }
        return frontWindowIsElsewhere(all: windowList([.optionAll, .excludeDesktopElements]),
                                      onScreen: windowList([.optionOnScreenOnly, .excludeDesktopElements]),
                                      pids: pids)
    }

    /// `all` is in the window server's front-to-back order; `onScreen` holds the
    /// windows of the current Space on each display.
    /// shortcut: assumes the browser's first window in that order is the one it
    /// opens links in; verify with the two-Space test checklist.
    static func frontWindowIsElsewhere(all: [[String: Any]], onScreen: [[String: Any]],
                                       pids: Set<pid_t>) -> Bool {
        guard let front = all.first(where: { isBrowserWindow($0, pids: pids) }) else { return false }
        let id = front[kCGWindowNumber as String] as? CGWindowID
        return !onScreen.contains { $0[kCGWindowNumber as String] as? CGWindowID == id }
    }

    /// Layer 0 drops picture-in-picture and other floating panels. The size floor
    /// drops helper windows (Chrome and Brave keep 30-px-high layer-0 strips).
    static func isBrowserWindow(_ window: [String: Any], pids: Set<pid_t>) -> Bool {
        guard let pid = window[kCGWindowOwnerPID as String] as? pid_t, pids.contains(pid),
              window[kCGWindowLayer as String] as? Int == 0,
              let bounds = window[kCGWindowBounds as String] as? NSDictionary,
              let rect = CGRect(dictionaryRepresentation: bounds)
        else { return false }
        return rect.width >= minEdge && rect.height >= minEdge
    }

    static let minEdge: CGFloat = 100

    private static func windowList(_ options: CGWindowListOption) -> [[String: Any]] {
        CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
    }
}
