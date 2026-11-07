import Testing
import Foundation
@testable import WindowOrganizer

struct LayoutTests {
    func display(_ id: String, x: Double = 0, y: Double = 0, w: Double = 1440, h: Double = 900) -> Display {
        Display(id: id, name: id, builtIn: false, frame: Frame(CGRect(x: x, y: y, width: w, height: h)),
                usable: Frame(CGRect(x: x, y: y + 25, width: w, height: h - 75)))
    }
    func saved(title: String = "Document", document: String? = nil) -> SavedWindow {
        SavedWindow(bundleID: "test.editor", appName: "Editor", title: title, document: document, displayID: "left", frame: Frame(CGRect(x: 0, y: 25, width: 720, height: 825)))
    }
    @Test func testDisplaySignatureIgnoresEnumerationOrder() {
        expectEqual(Geometry.signature([display("A"), display("B")]), Geometry.signature([display("B"), display("A")]))
        expectNotEqual(Geometry.signature([display("A")]), Geometry.signature([display("B")]))
    }
    @Test func testSameDisplayPreservesExactFrame() {
        let screen = display("A")
        let rect = Frame(CGRect(x: 100, y: 80, width: 600, height: 500))
        expectEqual(Geometry.restoredFrame(rect, from: screen, to: screen), rect.rect)
    }
    @Test func testRestoreScalesToLaptopUsableBounds() {
        let large = display("external", x: 1440, w: 2560, h: 1440)
        let laptop = display("laptop")
        let leftHalf = Frame(CGRect(x: 1440, y: 25, width: 1280, height: 1365))
        expectEqual(Geometry.restoredFrame(leftHalf, from: large, to: laptop), CGRect(x: 0, y: 25, width: 720, height: 825))
    }
    @Test func testNegativeOriginAndVerticalMonitorArrangement() {
        let old = display("left", x: -1440)
        let new = display("above", y: -900)
        let rect = Frame(CGRect(x: -1340, y: 100, width: 700, height: 500))
        expectEqual(Geometry.restoredFrame(rect, from: old, to: new), CGRect(x: 100, y: -800, width: 700, height: 500))
    }
    @Test func testOversizedAndOffscreenWindowClampsOnscreen() {
        let screen = display("A")
        let huge = Frame(CGRect(x: -1000, y: 2000, width: 4000, height: 3000))
        expectEqual(Geometry.restoredFrame(huge, from: screen, to: screen), screen.usable.rect)
    }
    @Test func testInvalidFrameFallsBackToUsableDisplay() {
        let screen = display("A")
        let invalid = Frame(CGRect(x: 0, y: 0, width: 0, height: 100))
        expectEqual(Geometry.restoredFrame(invalid, from: screen, to: screen), screen.usable.rect)
    }
    @Test func testSpanningWindowBelongsToDisplayWithGreatestOverlap() {
        let a = display("A")
        let b = display("B", x: 1440)
        expectEqual(Geometry.display(for: CGRect(x: 1300, y: 100, width: 800, height: 500), in: [a, b])?.id, "B")
    }
    @Test func testDocumentIdentitySurvivesTitleChange() {
        let candidates = [WindowIdentity(bundleID: "test.editor", title: "Renamed", document: "file:///a"), WindowIdentity(bundleID: "test.editor", title: "Other", document: "file:///b")]
        expectEqual(Matching.index(for: saved(document: "file:///a"), candidates: candidates, unused: [0, 1], savedAppCount: 2), 0)
    }
    @Test func testAmbiguousWindowsAreSkipped() {
        let candidates = [WindowIdentity(bundleID: "test.editor", title: "Document", document: nil), WindowIdentity(bundleID: "test.editor", title: "Document", document: nil)]
        expectNil(Matching.index(for: saved(), candidates: candidates, unused: [0, 1], savedAppCount: 2))
    }
    @Test func testUniqueSingleWindowCanChangeTitle() {
        let candidates = [WindowIdentity(bundleID: "test.editor", title: "New title", document: nil)]
        expectEqual(Matching.index(for: saved(), candidates: candidates, unused: [0], savedAppCount: 1), 0)
        expectNil(Matching.index(for: saved(), candidates: candidates, unused: [0], savedAppCount: 2))
    }
    @Test func testMatchedWindowCannotBeReusedOrCrossApps() {
        let candidates = [WindowIdentity(bundleID: "test.editor", title: "Document", document: nil), WindowIdentity(bundleID: "other.app", title: "Document", document: nil)]
        expectNil(Matching.index(for: saved(), candidates: candidates, unused: [1], savedAppCount: 1))
    }
    @Test func testOldLayoutsDecodeWithoutDesktopInformation() throws {
        let layout = Layout(name: "Old Desk", displays: [display("left")], windows: [saved()])
        let data = try JSONEncoder().encode(layout)
        let decoded = try JSONDecoder().decode(Layout.self, from: data)
        #expect(decoded.displays[0].spaces == nil)
        #expect(decoded.windows[0].spaceIDs == nil)
        #expect(decoded.desktopCount == 0)
    }
    @Test func testDesktopUUIDWinsAfterSpacesReordered() {
        let saved = DesktopSpace(id: 12, uuid: "A", index: 2, isActive: false, isFullscreen: false)
        let current = [DesktopSpace(id: 100, uuid: "A", index: 1, isActive: true, isFullscreen: false),
                       DesktopSpace(id: 101, uuid: "B", index: 2, isActive: false, isFullscreen: false)]
        #expect(SpaceMatching.target(for: saved, in: current)?.id == 100)
    }
    @Test func testDesktopOrderFallbackAfterRecreation() {
        let saved = DesktopSpace(id: 12, uuid: "old", index: 2, isActive: false, isFullscreen: false)
        let current = [DesktopSpace(id: 100, uuid: "new", index: 2, isActive: true, isFullscreen: false)]
        #expect(SpaceMatching.target(for: saved, in: current)?.id == 100)
        #expect(SpaceMatching.target(for: saved, in: []) == nil)
    }
    @Test func testFullscreenSpaceIsNeverRestoreTarget() {
        let saved = DesktopSpace(id: 12, uuid: "A", index: 2, isActive: false, isFullscreen: false)
        let current = [DesktopSpace(id: 12, uuid: "A", index: 2, isActive: true, isFullscreen: true)]
        #expect(SpaceMatching.target(for: saved, in: current) == nil)
    }
    @Test func testDesktopLayoutRoundTripPreservesEmptyDesktops() throws {
        var screen = display("left")
        screen.spaces = [DesktopSpace(id: 12, uuid: "A", index: 1, isActive: true, isFullscreen: false),
                         DesktopSpace(id: 13, uuid: "B", index: 2, isActive: false, isFullscreen: false)]
        var window = saved(); window.spaceIDs = [12]
        let layout = Layout(name: "Desk", displays: [screen], windows: [window])
        let decoded = try JSONDecoder().decode(Layout.self, from: JSONEncoder().encode(layout))
        #expect(decoded.displays[0].spaces == screen.spaces)
        #expect(decoded.windows[0].spaceIDs == [12])
        #expect(decoded.desktopCount == 2)
        #expect(decoded.desktopIndex(for: decoded.windows[0]) == 1)
    }
    @Test func testPresetsAndAutomaticAssignmentsRoundTrip() throws {
        let layout = Layout(name: "Desk", displays: [display("left")], windows: [saved()])
        var preferences = Preferences()
        preferences.layouts = [layout]
        preferences.autoSwitch = true
        preferences.assignments[layout.signature] = layout.id
        let decoded = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(preferences))
        expectEqual(decoded.layouts.first?.windows.first?.frame, layout.windows[0].frame)
        expectEqual(decoded.assignments[layout.signature], layout.id)
        expectTrue(decoded.autoSwitch)
    }
}

private func expectEqual<T: Equatable>(_ a: T, _ b: T, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(a == b, sourceLocation: sourceLocation)
}
private func expectNotEqual<T: Equatable>(_ a: T, _ b: T, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(a != b, sourceLocation: sourceLocation)
}
private func expectNil<T>(_ value: T?, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(value == nil, sourceLocation: sourceLocation)
}
private func expectTrue(_ value: Bool, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(value, sourceLocation: sourceLocation)
}
