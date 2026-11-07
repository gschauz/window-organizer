import AppKit
import ApplicationServices

struct LiveWindow {
    let element: AXUIElement
    let saved: SavedWindow
    var windowID: UInt32 = 0
    var identity: WindowIdentity { WindowIdentity(bundleID: saved.bundleID, title: saved.title, document: saved.document) }
}

struct Capture {
    var windows: [LiveWindow] = []
    var displays: [Display] = []
    var complete = true
    var notes: [String] = []
}

struct RestoreReport {
    var moved = 0
    var notes: [String] = []
    var undo: Layout?
}

enum WindowService {
    static var trusted: Bool { AXIsProcessTrusted() }

    static func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    static func displays() -> [Display] {
        let screens = NSScreen.screens
        let primaryHeight = screens.first(where: { screenID($0) == CGMainDisplayID() })?.frame.maxY ?? screens.first?.frame.maxY ?? 0
        func convert(_ r: CGRect) -> Frame {
            Frame(CGRect(x: r.minX, y: primaryHeight - r.maxY, width: r.width, height: r.height))
        }
        return screens.map { screen in
            let id = screenID(screen)
            let uuid = CGDisplayCreateUUIDFromDisplayID(id).map { CFUUIDCreateString(nil, $0.takeRetainedValue()) as String } ?? String(id)
            return Display(id: uuid, name: screen.localizedName, builtIn: CGDisplayIsBuiltin(id) != 0,
                           frame: convert(screen.frame), usable: convert(screen.visibleFrame))
        }
    }

    private static func screenID(_ screen: NSScreen) -> CGDirectDisplayID {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }

    static func attribute(_ element: AXUIElement, _ key: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, key as CFString, &result) == .success else { return nil }
        return result
    }

    static func frame(_ element: AXUIElement) -> CGRect? {
        guard let position = attribute(element, kAXPositionAttribute), CFGetTypeID(position) == AXValueGetTypeID(),
              let size = attribute(element, kAXSizeAttribute), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        var dimensions = CGSize.zero
        guard AXValueGetValue(position as! AXValue, .cgPoint, &point),
              AXValueGetValue(size as! AXValue, .cgSize, &dimensions) else { return nil }
        let result = CGRect(origin: point, size: dimensions)
        return Frame(result).valid ? result : nil
    }

    static func capture(displays: [Display]) -> Capture {
        let screens = SpaceService.snapshot(displays)
        guard trusted else { return Capture(displays: screens, complete: false, notes: ["Accessibility permission is required."]) }
        var result = Capture(displays: screens)
        var collected: [String: LiveWindow] = [:]
        func collect() {
            let pass = captureVisible(displays: screens)
            result.notes.append(contentsOf: pass.notes)
            for window in pass.windows {
                let key = window.windowID == 0 ? "ax-\(CFHash(window.element))" : "id-\(window.windowID)"
                collected[key] = window
            }
        }
        defer { SpaceService.restoreActiveSpaces(screens) }
        collect()
        for screen in screens {
            guard let spaces = screen.spaces else {
                result.notes.append("\(screen.name): desktop assignments could not be read."); continue
            }
            for space in spaces where !space.isFullscreen && !space.isActive {
                if SpaceService.activate(space, on: screen.id) { collect() }
                else { result.complete = false; result.notes.append("\(screen.name): could not inspect Desktop \(space.index). Some windows may be missing.") }
            }
        }
        result.windows = collected.values.sorted {
            if $0.saved.displayID != $1.saved.displayID { return $0.saved.displayID < $1.saved.displayID }
            if $0.saved.appName != $1.saved.appName { return $0.saved.appName < $1.saved.appName }
            return $0.windowID < $1.windowID
        }
        let readableApps = Set(result.windows.map { $0.saved.appName })
        result.notes = Array(Set(result.notes.filter { note in
            !readableApps.contains(where: { note == "\($0): windows could not be read." })
        })).sorted()
        return result
    }

    private static func captureVisible(displays: [Display]) -> Capture {
        var result = Capture()
        guard trusted else { result.notes.append("Accessibility permission is required."); return result }
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular && app.processIdentifier != getpid() {
            guard let bundle = app.bundleIdentifier else { continue }
            let name = app.localizedName ?? bundle
            let element = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(element, 0.4)
            var windowsValue: CFTypeRef?
            let status = AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &windowsValue)
            guard status == .success, let windows = windowsValue as? [AXUIElement] else {
                if status != .noValue && status != .attributeUnsupported { result.notes.append("\(name): windows could not be read.") }
                continue
            }
            for window in windows {
                AXUIElementSetMessagingTimeout(window, 0.4)
                guard attribute(window, kAXSubroleAttribute) as? String == kAXStandardWindowSubrole else { continue }
                if attribute(window, kAXMinimizedAttribute) as? Bool == true || attribute(window, "AXFullScreen") as? Bool == true {
                    result.notes.append("\(name): skipped a minimized or full-screen window.")
                    continue
                }
                var movable: DarwinBoolean = false
                var resizable: DarwinBoolean = false
                AXUIElementIsAttributeSettable(window, kAXPositionAttribute as CFString, &movable)
                AXUIElementIsAttributeSettable(window, kAXSizeAttribute as CFString, &resizable)
                guard movable.boolValue, resizable.boolValue, let rect = frame(window), let geometricScreen = Geometry.display(for: rect, in: displays) else {
                    result.notes.append("\(name): skipped a window that cannot be moved and resized.")
                    continue
                }
                let wid = SpaceService.windowID(window)
                let memberships = SpaceService.memberships(wid)
                let screen = displays.first { display in
                    display.spaces?.contains(where: { memberships?.contains($0.id) == true }) == true
                } ?? geometricScreen
                let saved = SavedWindow(bundleID: bundle, appName: name,
                                        title: attribute(window, kAXTitleAttribute) as? String ?? "",
                                        document: attribute(window, kAXDocumentAttribute) as? String,
                                        displayID: screen.id, frame: Frame(rect), spaceIDs: memberships)
                result.windows.append(LiveWindow(element: window, saved: saved, windowID: wid))
            }
        }
        return result
    }

    private static func setFrame(_ element: AXUIElement, _ rect: CGRect) {
        var point = rect.origin
        var size = rect.size
        guard let p = AXValueCreate(.cgPoint, &point), let s = AXValueCreate(.cgSize, &size) else { return }
        // Moving first gives apps the destination display's size constraints.
        AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, p)
        AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, s)
        AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, p)
    }

    private static func close(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) < 6 && abs(a.minY - b.minY) < 6 && abs(a.width - b.width) < 6 && abs(a.height - b.height) < 6
    }

    static func restore(_ layout: Layout, displays originalDisplays: [Display]) -> RestoreReport {
        var report = RestoreReport()
        guard trusted else { report.notes = ["Accessibility permission is required."]; return report }
        guard let fallback = originalDisplays.first else { report.notes = ["No displays are available."]; return report }
        let capture = capture(displays: originalDisplays)
        report.notes = capture.notes
        guard capture.complete else { report.notes.append("Restore cancelled because not all desktops could be read."); return report }
        report.undo = Layout(name: "Before \(layout.name)", displays: capture.displays, windows: capture.windows.map(\.saved))
        report.notes.append(contentsOf: SpaceService.ensureDesktops(for: layout, displays: originalDisplays))
        let displays = SpaceService.snapshot(originalDisplays)
        defer {
            for display in displays {
                if let savedDisplay = layout.displays.first(where: { $0.id == display.id }),
                   let selected = savedDisplay.spaces?.first(where: { $0.isActive && !$0.isFullscreen }),
                   let target = SpaceMatching.target(for: selected, in: display.spaces ?? []) {
                    SpaceService.activate(target, on: display.id)
                } else if let original = capture.displays.first(where: { $0.id == display.id })?.spaces?.first(where: \.isActive) {
                    SpaceService.activate(original, on: display.id)
                }
            }
        }
        let identities = capture.windows.map(\.identity)
        var unused = Set(identities.indices)
        var work: [(LiveWindow, CGRect, UInt64?)] = []
        for saved in layout.windows {
            let count = layout.windows.filter { $0.bundleID == saved.bundleID }.count
            guard let index = Matching.index(for: saved, candidates: identities, unused: unused, savedAppCount: count) else {
                report.notes.append("\(saved.appName) — \(saved.title.isEmpty ? "Untitled window" : saved.title): not open, unavailable, or ambiguous.")
                continue
            }
            unused.remove(index)
            guard let source = layout.displays.first(where: { $0.id == saved.displayID }) else {
                report.notes.append("\(saved.appName): saved display information is missing."); continue
            }
            let target = displays.first(where: { $0.id == source.id }) ?? fallback
            if target.id != source.id { report.notes.append("\(saved.appName): \(source.name) is disconnected; using \(target.name).") }
            let rect = Geometry.restoredFrame(saved.frame, from: source, to: target)
            let window = capture.windows[index]
            var expectedSpaceID: UInt64?
            if target.id == source.id, let memberships = saved.spaceIDs, !memberships.isEmpty {
                if memberships.count == 1,
                   let savedSpace = source.spaces?.first(where: { $0.id == memberships[0] }),
                   let destination = SpaceMatching.target(for: savedSpace, in: target.spaces ?? []) {
                    expectedSpaceID = destination.id
                    if !SpaceService.move(window.windowID, to: destination) {
                        report.notes.append("\(saved.appName): could not move to \(target.name), Desktop \(destination.index).")
                    }
                    // Some applications only accept geometry changes while their desktop is active.
                    SpaceService.activate(destination, on: target.id)
                } else if memberships.count == 1 {
                    report.notes.append("\(saved.appName): the saved desktop is unavailable; kept its current desktop.")
                    continue
                } else {
                    report.notes.append("\(saved.appName): this window belongs to multiple desktops; its desktop assignment was preserved.")
                }
            }
            setFrame(window.element, rect)
            work.append((window, rect, expectedSpaceID))
        }
        Thread.sleep(forTimeInterval: 0.18)
        for (window, rect, expectedSpaceID) in work {
            if frame(window.element).map({ close($0, rect) }) != true {
                if let expectedSpaceID, let display = displays.first(where: { $0.spaces?.contains(where: { $0.id == expectedSpaceID }) == true }),
                   let space = display.spaces?.first(where: { $0.id == expectedSpaceID }) { SpaceService.activate(space, on: display.id) }
                setFrame(window.element, rect)
                Thread.sleep(forTimeInterval: 0.08)
            }
            if let actual = frame(window.element), close(actual, rect) {
                if let expectedSpaceID, SpaceService.memberships(window.windowID)?.contains(expectedSpaceID) != true {
                    report.notes.append("\(window.saved.appName): position restored, but macOS did not keep it on the saved desktop.")
                } else { report.moved += 1 }
            }
            else { report.notes.append("\(window.saved.appName): could not reach the saved size or position (the app may enforce a minimum size).") }
        }
        return report
    }
}
