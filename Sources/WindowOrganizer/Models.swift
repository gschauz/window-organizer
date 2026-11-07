import Foundation
import CoreGraphics

struct Frame: Codable, Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    init(_ r: CGRect) { x = r.minX; y = r.minY; width = r.width; height = r.height }
    var rect: CGRect { CGRect(x: x, y: y, width: width, height: height) }
    var valid: Bool { [x, y, width, height].allSatisfy(\.isFinite) && width > 0 && height > 0 }
}

struct DesktopSpace: Codable, Identifiable, Equatable {
    var id: UInt64
    var uuid: String
    var index: Int
    var isActive: Bool
    var isFullscreen: Bool
}

enum SpaceMatching {
    static func target(for saved: DesktopSpace, in current: [DesktopSpace]) -> DesktopSpace? {
        let desktops = current.filter { !$0.isFullscreen }
        if !saved.uuid.isEmpty, let exact = desktops.first(where: { $0.uuid == saved.uuid }) { return exact }
        return desktops.first { $0.index == saved.index }
    }
}

struct Display: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var builtIn: Bool
    var frame: Frame
    var usable: Frame
    var spaces: [DesktopSpace]? = nil
}

struct SavedWindow: Codable, Identifiable {
    var id = UUID()
    var bundleID: String
    var appName: String
    var title: String
    var document: String?
    var displayID: String
    var frame: Frame
    var spaceIDs: [UInt64]? = nil
}

struct Layout: Codable, Identifiable {
    var id = UUID()
    var name: String
    var savedAt = Date()
    var displays: [Display]
    var windows: [SavedWindow]
    var signature: String { Geometry.signature(displays) }
    var desktopCount: Int { displays.reduce(0) { $0 + ($1.spaces?.filter { !$0.isFullscreen }.count ?? 0) } }
    var summary: String {
        let base = "\(windows.count) \(windows.count == 1 ? "window" : "windows") · \(displays.count) \(displays.count == 1 ? "monitor" : "monitors")"
        return desktopCount > 0 ? base + " · \(desktopCount) \(desktopCount == 1 ? "desktop" : "desktops")" : base
    }
    func desktopIndex(for window: SavedWindow) -> Int? {
        guard let ids = window.spaceIDs, ids.count == 1 else { return nil }
        return displays.first { $0.id == window.displayID }?.spaces?.first { $0.id == ids[0] }?.index
    }
}

struct Preferences: Codable {
    var version = 1
    var layouts: [Layout] = []
    var autoSwitch = false
    var assignments: [String: UUID] = [:]
}

enum Geometry {
    static func signature(_ displays: [Display]) -> String { displays.map(\.id).sorted().joined(separator: "|") }

    static func display(for frame: CGRect, in displays: [Display]) -> Display? {
        displays.max { a, b in
            let x = frame.intersection(a.frame.rect)
            let y = frame.intersection(b.frame.rect)
            return (x.isNull ? 0 : x.width * x.height) < (y.isNull ? 0 : y.width * y.height)
        }
    }

    // Positions are relative to usable display bounds, preserving intent after scaling,
    // Dock changes, monitor rearrangement, and resolution changes.
    static func restoredFrame(_ saved: Frame, from source: Display, to target: Display) -> CGRect {
        let old = source.usable.rect
        let new = target.usable.rect
        guard saved.valid, old.width > 0, old.height > 0, new.width > 0, new.height > 0 else { return new }
        let width = min(new.width, max(100, saved.width / old.width * new.width))
        let height = min(new.height, max(80, saved.height / old.height * new.height))
        let x = new.minX + (saved.x - old.minX) / old.width * new.width
        let y = new.minY + (saved.y - old.minY) / old.height * new.height
        return CGRect(x: min(max(new.minX, x), new.maxX - width).rounded(),
                      y: min(max(new.minY, y), new.maxY - height).rounded(),
                      width: width.rounded(), height: height.rounded())
    }
}

struct WindowIdentity {
    var bundleID: String
    var title: String
    var document: String?
}

enum Matching {
    // Never guess between multiple ambiguous windows of the same app.
    static func index(for saved: SavedWindow, candidates: [WindowIdentity], unused: Set<Int>, savedAppCount: Int) -> Int? {
        let app = unused.filter { candidates[$0].bundleID == saved.bundleID }
        if let document = saved.document, !document.isEmpty {
            let matches = app.filter { candidates[$0].document == document }
            if matches.count == 1 { return matches.first }
        }
        if !saved.title.isEmpty {
            let matches = app.filter { candidates[$0].title == saved.title }
            if matches.count == 1 { return matches.first }
        }
        if savedAppCount == 1 && app.count == 1 { return app.first }
        return nil
    }
}
