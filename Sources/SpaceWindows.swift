import AppKit

/// Chooses where a link opens so that macOS does not switch Spaces.
/// It uses only the public window list and reads no window titles, so it needs
/// no Screen Recording permission.
enum SpaceWindows {
    enum Plan: Equatable {
        /// Open as usual: the browser's last-used window is visible (or none is needed).
        case asIs
        /// Bring the visible browser window with these bounds to the front, then open.
        case raise(CGRect)
        /// Open a new window.
        case newWindow
    }

    /// The plan for a browser. `display` limits the search to one display's
    /// visible frame (top-left global coordinates); nil means every display.
    static func plan(bundleID: String, display: CGRect?) -> Plan {
        plan(all: windowList([.optionAll, .excludeDesktopElements]),
             onScreen: windowList([.optionOnScreenOnly, .excludeDesktopElements]),
             pids: pids(of: bundleID), display: display)
    }

    /// `all` is in the window server's front-to-back order; `onScreen` holds the
    /// windows of the visible Space on each display.
    /// shortcut: assumes the browser's first window in that order is the one it
    /// opens links in; verify with the multi-display test checklist.
    static func plan(all: [[String: Any]], onScreen: [[String: Any]],
                     pids: Set<pid_t>, display: CGRect?) -> Plan {
        let windows = all.filter { isBrowserWindow($0, pids: pids) }
        let visibleIDs = Set(onScreen.compactMap(id))
        let visible = windows.filter { window in
            guard let wid = id(window), visibleIDs.contains(wid), let rect = bounds(window) else { return false }
            return display.map { $0.contains(CGPoint(x: rect.midX, y: rect.midY)) } ?? true
        }
        if windows.isEmpty { return display == nil ? .asIs : .newWindow }
        if let first = visible.first, id(first) == id(windows[0]) { return .asIs }
        if let first = visible.first, let rect = bounds(first) { return .raise(rect) }
        return .newWindow
    }

    /// Layer 0 drops picture-in-picture and other floating panels. The size floor
    /// drops helper windows (Chrome and Brave keep 30-px-high layer-0 strips).
    static func isBrowserWindow(_ window: [String: Any], pids: Set<pid_t>) -> Bool {
        guard let pid = window[kCGWindowOwnerPID as String] as? pid_t, pids.contains(pid),
              window[kCGWindowLayer as String] as? Int == 0,
              let rect = bounds(window)
        else { return false }
        return rect.width >= minEdge && rect.height >= minEdge
    }

    static let minEdge: CGFloat = 100

    /// The visible frame (top-left global coordinates) of the display that holds
    /// the frontmost normal window of another app.
    static func activeDisplayFrame() -> CGRect? {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        guard let front = windowList([.optionOnScreenOnly, .excludeDesktopElements]).first(where: {
                  ($0[kCGWindowOwnerPID as String] as? pid_t) != ownPID
                      && $0[kCGWindowLayer as String] as? Int == 0
                      && (bounds($0).map { $0.width >= minEdge && $0.height >= minEdge } ?? false)
              }),
              let rect = bounds(front) else { return nil }
        var displayID = CGDirectDisplayID()
        var count: UInt32 = 0
        guard CGGetDisplaysWithPoint(CGPoint(x: rect.midX, y: rect.midY), 1, &displayID, &count) == .success,
              count == 1,
              let screen = NSScreen.screens.first(where: {
                  ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == displayID
              }),
              let primaryHeight = NSScreen.screens.first?.frame.height
        else { return nil }
        // AppKit frames start bottom-left; the window list starts top-left.
        let frame = screen.visibleFrame
        return CGRect(x: frame.minX, y: primaryHeight - frame.maxY, width: frame.width, height: frame.height)
    }

    static func pids(of bundleID: String) -> Set<pid_t> {
        Set(NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).map(\.processIdentifier))
    }

    private static func id(_ window: [String: Any]) -> CGWindowID? {
        window[kCGWindowNumber as String] as? CGWindowID
    }

    static func bounds(_ window: [String: Any]) -> CGRect? {
        (window[kCGWindowBounds as String] as? NSDictionary).flatMap { CGRect(dictionaryRepresentation: $0) }
    }

    private static func windowList(_ options: CGWindowListOption) -> [[String: Any]] {
        CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
    }
}
