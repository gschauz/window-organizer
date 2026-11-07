import AppKit
import ApplicationServices
import SpaceBridge

// All desktop operations are verified against WindowServer's actual state.
// IDs are session-specific; saved UUIDs and per-monitor desktop order are used
// to resolve a layout after reconnects or a restart.
enum SpaceService {
    static func rawDisplays() -> [[String: Any]] { WODisplaySpaces() as? [[String: Any]] ?? [] }

    static func snapshot(_ displays: [Display]) -> [Display] {
        let raw = rawDisplays()
        return displays.map { display in
            var result = display
            guard let data = raw.first(where: {
                ($0["Display Identifier"] as? String) == display.id ||
                (($0["Display Identifier"] as? String) == "Main" && display.frame.x == 0 && display.frame.y == 0)
            }), let list = data["Spaces"] as? [[String: Any]] else { return result }
            let active = (data["Current Space"] as? [String: Any])?["ManagedSpaceID"] as? NSNumber
            var desktopIndex = 0
            result.spaces = list.compactMap { entry in
                guard let id = entry["ManagedSpaceID"] as? NSNumber, let type = entry["type"] as? NSNumber else { return nil }
                let fullscreen = type.intValue != 0
                if !fullscreen { desktopIndex += 1 }
                return DesktopSpace(id: id.uint64Value, uuid: entry["uuid"] as? String ?? "",
                                    index: fullscreen ? 0 : desktopIndex, isActive: id == active, isFullscreen: fullscreen)
            }
            return result
        }
    }

    static func windowID(_ element: AXUIElement) -> UInt32 { WOWindowID(element) }
    static func memberships(_ windowID: UInt32) -> [UInt64]? {
        guard windowID != 0, let numbers = WOSpacesForWindow(windowID) else { return nil }
        return numbers.map(\.uint64Value)
    }

    static func nativeDisplayID(_ displayID: String) -> String? {
        let raw = rawDisplays()
        if raw.contains(where: { $0["Display Identifier"] as? String == displayID }) { return displayID }
        if raw.count == 1, raw.first?["Display Identifier"] as? String == "Main" { return "Main" }
        return nil
    }

    static func activeID(_ displayID: String) -> UInt64? {
        guard let native = nativeDisplayID(displayID), let data = rawDisplays().first(where: { $0["Display Identifier"] as? String == native }) else { return nil }
        return ((data["Current Space"] as? [String: Any])?["ManagedSpaceID"] as? NSNumber)?.uint64Value
    }

    @discardableResult
    static func activate(_ space: DesktopSpace, on displayID: String) -> Bool {
        if activeID(displayID) == space.id { return true }
        guard let native = nativeDisplayID(displayID), WOActivateSpace(native, space.id) else { return false }
        for _ in 0..<20 {
            Thread.sleep(forTimeInterval: 0.05)
            if activeID(displayID) == space.id { Thread.sleep(forTimeInterval: 0.12); return true }
        }
        return false
    }

    static func restoreActiveSpaces(_ displays: [Display]) {
        for display in displays {
            if let active = display.spaces?.first(where: \.isActive) { activate(active, on: display.id) }
        }
    }

    static func move(_ windowID: UInt32, to space: DesktopSpace) -> Bool {
        guard !space.isFullscreen, windowID != 0 else { return false }
        if memberships(windowID)?.contains(space.id) == true { return true }
        guard WOMoveWindowToSpace(windowID, space.id) else { return false }
        for _ in 0..<20 {
            Thread.sleep(forTimeInterval: 0.05)
            if memberships(windowID)?.contains(space.id) == true { return true }
        }
        return false
    }

    // Creating desktops uses the same Add Desktop button as Mission Control.
    // Never remove surplus desktops: they may contain unrelated or unsaved work.
    static func ensureDesktops(for layout: Layout, displays: [Display]) -> [String] {
        var notes: [String] = []
        for saved in layout.displays {
            let count = saved.spaces?.filter { !$0.isFullscreen }.count ?? 0
            guard count > 0, displays.contains(where: { $0.id == saved.id }) else { continue }
            var live = snapshot(displays).first { $0.id == saved.id }
            var current = live?.spaces?.filter { !$0.isFullscreen }.count ?? 0
            guard current > 0 else { notes.append("\(saved.name): desktop information is unavailable."); continue }
            if current > count { notes.append("\(saved.name): kept \(current - count) additional desktops to preserve other windows.") }
            while current < min(count, 16) {
                guard MissionControl.addDesktop(displayID: saved.id) else {
                    notes.append("\(saved.name): could not create Desktop \(current + 1). Please add it in Mission Control, then restore again.")
                    break
                }
                live = snapshot(displays).first { $0.id == saved.id }
                let updated = live?.spaces?.filter { !$0.isFullscreen }.count ?? current
                guard updated > current else { notes.append("\(saved.name): macOS did not create the missing desktop."); break }
                current = updated
            }
        }
        return notes
    }
}

private enum MissionControl {
    static func children(_ element: AXUIElement) -> [AXUIElement] { WindowService.attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? [] }
    static func find(_ identifier: String, under root: AXUIElement, depth: Int = 5) -> AXUIElement? {
        if WindowService.attribute(root, kAXIdentifierAttribute) as? String == identifier { return root }
        guard depth > 0 else { return nil }
        for child in children(root) { if let match = find(identifier, under: child, depth: depth - 1) { return match } }
        return nil
    }
    static func addDesktop(displayID: String) -> Bool {
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else { return false }
        let root = AXUIElementCreateApplication(dock.processIdentifier)
        AXUIElementSetMessagingTimeout(root, 0.3)
        let wasOpen = find("mc", under: root, depth: 1) != nil
        if !wasOpen {
            _ = DispatchQueue.main.sync {
                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Mission Control.app"))
            }
        }
        defer {
            if !wasOpen {
                let down = CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: true)
                let up = CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: false)
                down?.post(tap: .cghidEventTap); up?.post(tap: .cghidEventTap)
                Thread.sleep(forTimeInterval: 0.25)
            }
        }
        var group: AXUIElement?
        for _ in 0..<20 {
            group = find("mc", under: root, depth: 1)
            if group != nil { break }
            Thread.sleep(forTimeInterval: 0.1)
        }
        guard let group else { return false }
        Thread.sleep(forTimeInterval: 0.3)
        let screenID: UInt32? = DispatchQueue.main.sync {
            NSScreen.screens.compactMap { screen -> UInt32? in
                guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
                      let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue(),
                      CFUUIDCreateString(nil, uuid) as String == displayID else { return nil }
                return number.uint32Value
            }.first
        }
        guard let screenID, let screen = children(group).first(where: {
            (WindowService.attribute($0, "AXDisplayID") as? NSNumber)?.uint32Value == screenID
        }), let add = find("mc.spaces.add", under: screen) else { return false }
        let result = AXUIElementPerformAction(add, kAXPressAction as CFString) == .success
        Thread.sleep(forTimeInterval: 0.35)
        return result
    }
}
