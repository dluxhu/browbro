// Self-check for Sources/SpaceWindows.swift. Run: scripts/check-space-windows.sh
import AppKit

func window(_ id: CGWindowID, pid: pid_t, layer: Int = 0, x: CGFloat = 0,
            size: CGSize = CGSize(width: 1200, height: 800)) -> [String: Any] {
    [kCGWindowNumber as String: NSNumber(value: id),
     kCGWindowOwnerPID as String: NSNumber(value: pid),
     kCGWindowLayer as String: NSNumber(value: layer),
     kCGWindowBounds as String: CGRect(origin: CGPoint(x: x, y: 0), size: size).dictionaryRepresentation]
}

var failures = 0
func check(_ name: String, _ all: [[String: Any]], onScreen: [[String: Any]],
           pids: Set<pid_t> = [10], display: CGRect? = nil, expect: SpaceWindows.Plan) {
    let got = SpaceWindows.plan(all: all, onScreen: onScreen, pids: pids, display: display)
    print(got == expect ? "ok  " : "FAIL", name, got == expect ? "" : "(got \(got))")
    if got != expect { failures += 1 }
}
func rect(_ w: [String: Any]) -> CGRect { SpaceWindows.bounds(w)! }

// Display A spans x 0..<1920, display B x 1920..<3840.
let displayA = CGRect(x: 0, y: 0, width: 1920, height: 1080)
let here = window(1, pid: 10), away = window(2, pid: 10)
let onB = window(7, pid: 10, x: 2000)

check("no browser window, any display", [window(9, pid: 99)], onScreen: [], expect: .asIs)
check("no browser window, this display", [window(9, pid: 99)], onScreen: [], display: displayA, expect: .newWindow)
check("front window visible", [here, away], onScreen: [here], expect: .asIs)
check("front window hidden, one visible", [away, here], onScreen: [here], expect: .raise(rect(here)))
check("only hidden windows", [away], onScreen: [], expect: .newWindow)
let strip = window(3, pid: 10, size: CGSize(width: 1920, height: 30))
check("helper strip in front is skipped", [strip, away], onScreen: [strip], expect: .newWindow)
let pip = window(4, pid: 10, layer: 3)
check("picture-in-picture in front is skipped", [pip, away], onScreen: [pip], expect: .newWindow)
check("other app's window in front is skipped", [window(5, pid: 99), here], onScreen: [here], expect: .asIs)
let second = window(6, pid: 11)
check("second instance's front window counts", [second, here], onScreen: [here],
      pids: [10, 11], expect: .raise(rect(here)))
check("visible on display B, any display", [onB, away], onScreen: [onB], expect: .asIs)
check("visible on display B only, this display", [onB, away], onScreen: [onB], display: displayA, expect: .newWindow)
check("visible on both, front on B, this display", [onB, here], onScreen: [onB, here], display: displayA,
      expect: .raise(rect(here)))
check("front visible on this display", [here, onB], onScreen: [here, onB], display: displayA, expect: .asIs)

// Real window list: print, do not assert (the windows on this Mac vary).
print("live active display frame =", SpaceWindows.activeDisplayFrame().map { "\($0)" } ?? "nil")
for id in ["com.google.Chrome", "com.brave.Browser", "com.apple.Safari", "org.mozilla.firefox"] {
    print("live", id, "plan =", SpaceWindows.plan(bundleID: id, display: nil))
}
exit(failures == 0 ? 0 : 1)
