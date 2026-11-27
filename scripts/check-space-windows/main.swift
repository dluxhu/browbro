// Self-check for Sources/SpaceWindows.swift. Run: scripts/check-space-windows.sh
import AppKit

func window(_ id: CGWindowID, pid: pid_t, layer: Int = 0,
            size: CGSize = CGSize(width: 1200, height: 800)) -> [String: Any] {
    [kCGWindowNumber as String: NSNumber(value: id),
     kCGWindowOwnerPID as String: NSNumber(value: pid),
     kCGWindowLayer as String: NSNumber(value: layer),
     kCGWindowBounds as String: CGRect(origin: .zero, size: size).dictionaryRepresentation]
}

var failures = 0
func check(_ name: String, _ all: [[String: Any]], onScreen: [[String: Any]],
           pids: Set<pid_t> = [10], expect: Bool) {
    let got = SpaceWindows.frontWindowIsElsewhere(all: all, onScreen: onScreen, pids: pids)
    print(got == expect ? "ok  " : "FAIL", name)
    if got != expect { failures += 1 }
}

let here = window(1, pid: 10), away = window(2, pid: 10)
check("no browser window anywhere", [window(9, pid: 99)], onScreen: [], expect: false)
check("front window in this Space", [here, away], onScreen: [here], expect: false)
check("front window elsewhere, one here", [away, here], onScreen: [here], expect: true)
check("only windows elsewhere", [away], onScreen: [], expect: true)
let strip = window(3, pid: 10, size: CGSize(width: 1920, height: 30))
check("helper strip in front is skipped", [strip, away], onScreen: [strip], expect: true)
let pip = window(4, pid: 10, layer: 3)
check("picture-in-picture in front is skipped", [pip, away], onScreen: [pip], expect: true)
check("other app's window in front is skipped", [window(5, pid: 99), here], onScreen: [here], expect: false)
let second = window(6, pid: 11)
check("second instance's front window counts", [second, here], onScreen: [here],
      pids: [10, 11], expect: true)

// Real window list: print, do not assert (the windows on this Mac vary).
for id in ["com.google.Chrome", "com.brave.Browser", "com.apple.Safari", "org.mozilla.firefox"] {
    print("live", id, "frontWindowIsElsewhere =", SpaceWindows.frontWindowIsElsewhere(bundleID: id))
}
exit(failures == 0 ? 0 : 1)
