import AppKit
import ApplicationServices

/// Raises and moves browser windows through the Accessibility API. Every call
/// needs the Accessibility permission; BrowBro asks for it only when the user
/// turns on "Only on the current display".
enum AXWindows {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Shows the system prompt (once per app) and returns the current state.
    static func requestTrust() -> Bool {
        AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
    }

    static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!

    /// Raises the one window of `pids` with these bounds, makes it main, and
    /// returns its app. Nil when no window or more than one window matches,
    /// or when the raise fails.
    static func raise(bounds: CGRect, pids: Set<pid_t>) -> NSRunningApplication? {
        let matches = pids.flatMap { pid in windows(of: pid).filter { frame($0)?.isClose(to: bounds) ?? false }.map { (pid, $0) } }
        guard matches.count == 1, let (pid, window) = matches.first else { return nil }
        // The window can close in the meantime: then the caller opens a new window.
        guard AXUIElementPerformAction(window, kAXRaiseAction as CFString) == .success,
              AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue) == .success
        else { return nil }
        return NSRunningApplication(processIdentifier: pid)
    }

    /// Every standard window of the app, for `moveNewWindow(of:excluding:to:)`.
    static func windows(ofBundleID bundleID: String) -> [AXUIElement] {
        SpaceWindows.pids(of: bundleID).flatMap(windows(of:))
    }

    /// Waits up to 3 s for a window of the app that is not in `known`, then
    /// moves it into `target` (top-left global coordinates) and shrinks it to fit.
    static func moveNewWindow(of bundleID: String, excluding known: [AXUIElement], to target: CGRect, attempt: Int = 0) {
        let fresh = windows(ofBundleID: bundleID).first { window in !known.contains { CFEqual($0, window) } }
        guard let window = fresh, let current = frame(window) else {
            if attempt < 30 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    moveNewWindow(of: bundleID, excluding: known, to: target, attempt: attempt + 1)
                }
            }
            return
        }
        var origin = target.origin
        var size = CGSize(width: min(current.width, target.width), height: min(current.height, target.height))
        if let value = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value)
        }
        if let value = AXValueCreate(.cgPoint, &origin) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
        }
    }

    private static func windows(of pid: pid_t) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(AXUIElementCreateApplication(pid), kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else { return [] }
        return windows.filter { string($0, kAXSubroleAttribute) == kAXStandardWindowSubrole as String }
    }

    private static func frame(_ window: AXUIElement) -> CGRect? {
        var position = CGPoint.zero, size = CGSize.zero
        guard let p = attribute(window, kAXPositionAttribute), AXValueGetValue(p as! AXValue, .cgPoint, &position),
              let s = attribute(window, kAXSizeAttribute), AXValueGetValue(s as! AXValue, .cgSize, &size)
        else { return nil }
        return CGRect(origin: position, size: size)
    }

    private static func string(_ element: AXUIElement, _ name: String) -> String? {
        attribute(element, name) as? String
    }

    private static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }
}

private extension CGRect {
    /// AX and the window list can round differently.
    func isClose(to other: CGRect) -> Bool {
        abs(minX - other.minX) <= 1 && abs(minY - other.minY) <= 1
            && abs(width - other.width) <= 1 && abs(height - other.height) <= 1
    }
}
