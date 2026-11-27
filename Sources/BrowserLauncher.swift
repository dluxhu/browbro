import AppKit
import os

private let launchLog = Logger(subsystem: "cloud.tiagomoraes.browbro", category: "launch")

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

    /// Open a URL by invoking the browser with launch flags (`--profile-directory`,
    /// `--incognito`, `--private-window`, …).
    ///
    /// Flags are only honored as process arguments — `NSWorkspace.open(urls:…)`
    /// drops them. These browsers dedupe to their running instance, so this
    /// opens the right window whether or not the browser is already open
    /// (verified live for Chrome and Firefox — ADR-0001).
    ///
    /// Direct (DMG/Homebrew) builds spawn the bundle executable. The Mac App
    /// Store sandbox forbids that, so those builds go through
    /// `NSWorkspace.openApplication` with `OpenConfiguration.arguments` instead.
    @discardableResult
    static func open(_ url: URL, withBinaryOfAppAt appURL: URL, flags: [String]) -> Bool {
        #if APPSTORE
        return openViaWorkspace(url, appAt: appURL, flags: flags)
        #else
        return openViaProcess(url, appAt: appURL, flags: flags)
        #endif
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
        if Preferences.openInCurrentSpace, SpaceWindows.frontWindowIsElsewhere(bundleID: target.bundleID) {
            if let flag = newWindowFlag(for: target) {
                flags.append(flag)
            } else if openSafariWindow(url, target: target) {
                return
            }
        }
        if flags.isEmpty {
            open(url, withAppAt: target.appURL)
        } else {
            open(url, withBinaryOfAppAt: target.appURL, flags: flags)
        }
    }

    /// The launch argument that opens a new window. Every Private-Window-capable
    /// browser (the Chromium and Firefox families) takes `--new-window`.
    private static func newWindowFlag(for target: LaunchTarget) -> String? {
        guard PrivateWindow.capability(for: target.bundleID) != nil else { return nil }
        // Firefox's --private-window takes the URL as its value and opens a window.
        // A second flag would open the link in a normal window.
        return target.privateFlag == "--private-window" ? nil : "--new-window"
    }

    /// Open the URL in a new Safari window through Apple Events. Returns false
    /// when Safari is not the target or the App Store build is running: the
    /// caller then opens the URL as usual.
    private static func openSafariWindow(_ url: URL, target: LaunchTarget) -> Bool {
        #if APPSTORE
        return false
        #else
        guard target.bundleID == "com.apple.Safari" else { return false }
        // The URL comes from any app: escape it for an AppleScript string literal.
        let literal = url.absoluteString
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = """
            tell application id "com.apple.Safari"
                make new document with properties {URL:"\(literal)"}
                activate
            end tell
            """
        // Off the main thread: the first run waits for the Automation consent prompt.
        scriptQueue.async {
            var error: NSDictionary?
            NSAppleScript(source: source)?.executeAndReturnError(&error)
            if let error {
                launchLog.error("Safari new window failed: \(error, privacy: .public)")
                open(url, withAppAt: target.appURL)
            }
        }
        return true
        #endif
    }

    #if !APPSTORE
    /// NSAppleScript is not thread-safe: run every script on one serial queue.
    private static let scriptQueue = DispatchQueue(label: "browbro.safari-script", qos: .userInitiated)
    #endif

    #if APPSTORE
    /// Sandbox-legal launch: Launch Services delivers the flags. `arguments` is
    /// ignored when opening URLs, so the URL goes on the argument list too, and
    /// a new instance is spawned so a running browser actually receives them
    /// (Chromium/Firefox then forward to the existing process and exit).
    private static func openViaWorkspace(_ url: URL, appAt appURL: URL, flags: [String]) -> Bool {
        let config = NSWorkspace.OpenConfiguration()
        config.arguments = flags + [url.absoluteString]
        config.activates = true
        config.createsNewApplicationInstance = true
        launchLog.info("workspace launch \(appURL.lastPathComponent, privacy: .public) flags=\(flags.joined(separator: " "), privacy: .public)")
        NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, error in
            if let error {
                launchLog.error("workspace launch failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        return true
    }
    #else
    /// Direct binary invocation. The binary comes from the bundle's
    /// CFBundleExecutable — Firefox's is `firefox`, Chrome's is `Google Chrome`.
    private static func openViaProcess(_ url: URL, appAt appURL: URL, flags: [String]) -> Bool {
        guard let binary = Bundle(url: appURL)?.executableURL else { return false }
        let process = Process()
        process.executableURL = binary
        process.arguments = flags + [url.absoluteString]
        do {
            try process.run()
            return true
        } catch {
            launchLog.error("process launch failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
    #endif
}
