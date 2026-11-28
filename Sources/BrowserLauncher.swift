import AppKit

/// Opens URLs in browsers — including a specific Chrome profile.
enum BrowserLauncher {

    /// Open a URL in an arbitrary browser app bundle.
    static func open(_ url: URL, withAppAt appURL: URL, completion: ((Error?) -> Void)? = nil) {
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: config) { _, error in
            completion?(error)
        }
    }

    /// The Google Chrome app bundle, if installed.
    static func chromeAppURL() -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.google.Chrome")
    }

    /// Open a URL by invoking the browser's *binary* directly with launch flags.
    ///
    /// Flags like `--profile-directory` and `--incognito` are only honored as launch
    /// arguments — `NSWorkspace.open` can't deliver them to a running app. These
    /// browsers dedupe to their running instance, so this opens the right window
    /// whether or not the browser is already open (verified live for Chrome and
    /// Firefox — ADR-0001). The binary comes from the bundle's CFBundleExecutable.
    @discardableResult
    static func open(_ url: URL, withBinaryOfAppAt appURL: URL, flags: [String]) -> Bool {
        guard let binary = Bundle(url: appURL)?.executableURL else { return false }
        let process = Process()
        process.executableURL = binary
        process.arguments = flags + [url.absoluteString]
        do {
            try process.run()
            return true
        } catch {
            return false
        }
    }

    /// Launch a resolved target (browser, Chrome profile, or a Private Window
    /// variant of either) with a URL.
    static func launch(_ target: LaunchTarget, url: URL) {
        var flags: [String] = []
        if case .chromeProfile(let directory) = target.kind {
            flags.append("--profile-directory=\(directory)")
        }
        if let privateFlag = target.privateFlag {
            flags.append(privateFlag)
        }
        guard Preferences.openInCurrentSpace else { return open(url, target: target, flags: flags) }
        let trusted = AXWindows.isTrusted
        let display = Preferences.currentDisplayOnly && trusted ? SpaceWindows.activeDisplayFrame() : nil
        switch SpaceWindows.plan(bundleID: target.bundleID, display: display) {
        case .asIs:
            break
        case .raise(let bounds):
            if trusted, let app = AXWindows.raise(bounds: bounds, pids: SpaceWindows.pids(of: target.bundleID)) {
                // The browser opens links in its last-active window: activate it first.
                app.activate()
                whenActive(app) { open(url, target: target, flags: flags) }
                return
            }
            fallthrough
        case .newWindow:
            guard let flag = newWindowFlag(for: target) else { break }
            let known = display == nil ? [] : AXWindows.windows(ofBundleID: target.bundleID)
            open(url, target: target, flags: flags + [flag])
            if let display { AXWindows.moveNewWindow(of: target.bundleID, excluding: known, to: display) }
            return
        }
        open(url, target: target, flags: flags)
    }

    private static func open(_ url: URL, target: LaunchTarget, flags: [String]) {
        if flags.isEmpty {
            open(url, withAppAt: target.appURL)
        } else {
            open(url, withBinaryOfAppAt: target.appURL, flags: flags)
        }
    }

    /// Runs `action` once the app is active, or after 1 s.
    private static func whenActive(_ app: NSRunningApplication, attempt: Int = 0, _ action: @escaping () -> Void) {
        if app.isActive || attempt >= 20 { return action() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { whenActive(app, attempt: attempt + 1, action) }
    }

    /// The launch argument that opens a new window. Every Private-Window-capable
    /// browser (the Chromium and Firefox families) takes `--new-window`.
    private static func newWindowFlag(for target: LaunchTarget) -> String? {
        guard PrivateWindow.capability(for: target.bundleID) != nil else { return nil }
        // Firefox's --private-window takes the URL as its value and opens a window.
        // A second flag would open the link in a normal window.
        return target.privateFlag == "--private-window" ? nil : "--new-window"
    }
}
