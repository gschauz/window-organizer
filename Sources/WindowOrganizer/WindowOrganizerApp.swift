import SwiftUI
import AppKit
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let store = AppStore()
    private var dashboard: NSWindow?
    private let dashboardWidth: CGFloat = 848
    private var settingsWindow: NSWindow?
    private var dashboardContentHeight: CGFloat = 0
    private var dashboardResizeScheduled = false
    private var screenObserver: NSObjectProtocol?
    private var updateStatusSubscription: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
        NSApp.setActivationPolicy(.regular)
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            self?.scheduleDashboardResize()
        }
        showDashboard()
        reportUpdateAccess()
        if CommandLine.arguments.contains("--request-update-access"), !WindowService.trusted {
            WindowService.requestPermission()
        }
    }

    // The updater must check the running GUI app's permission, not a shell helper's.
    private func reportUpdateAccess() {
        guard let index = CommandLine.arguments.firstIndex(of: "--update-status-file"),
              CommandLine.arguments.indices.contains(index + 1) else { return }
        let destination = URL(fileURLWithPath: CommandLine.arguments[index + 1])
        updateStatusSubscription = store.$hasPermission.removeDuplicates().sink { granted in
            do {
                let data = try JSONSerialization.data(withJSONObject: [
                    "accessibilityGranted": granted,
                    "pid": ProcessInfo.processInfo.processIdentifier,
                    "appPath": Bundle.main.bundleURL.path
                ], options: [.sortedKeys])
                try data.write(to: destination, options: .atomic)
            } catch {
                NSLog("Could not report update status: %@", error.localizedDescription)
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showDashboard()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func confirmLayoutUpdate(_ layout: Layout) {
        guard !store.busy, store.hasPermission else { return }
        showDashboard()
        guard let dashboard else { return }
        let alert = NSAlert()
        alert.messageText = "Replace this saved layout?"
        alert.informativeText = "The current window positions and connected displays will replace \(layout.name)’s saved layout."
        alert.addButton(withTitle: "Update layout")
        alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: dashboard) { [weak self] response in
            guard response == .alertFirstButtonReturn,
                  let self,
                  !self.store.busy, self.store.hasPermission,
                  let current = self.store.preferences.layouts.first(where: { $0.id == layout.id }) else { return }
            self.store.save(name: current.name, replacing: current.id)
        }
    }

    func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 510, height: 460),
                                  styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "Settings"
            Theme.configure(window)
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: OrganizerSettingsView(store: store))
            window.center()
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showDashboard() {
        if dashboard == nil {
            let available = NSScreen.main?.visibleFrame.size ?? NSSize(width: dashboardWidth, height: 760)
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: min(dashboardWidth, available.width), height: min(760, available.height)),
                                  styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "Window Organizer"
            Theme.configure(window)
            window.collectionBehavior.insert(.fullScreenNone)
            window.delegate = self
            window.isReleasedWhenClosed = false
            dashboard = window
            window.contentView = NSHostingView(rootView: DashboardView(onContentHeightChange: { [weak self] height in
                guard let self, height > 0, abs(self.dashboardContentHeight - height) > 0.5 else { return }
                self.dashboardContentHeight = height
                self.scheduleDashboardResize()
            }).environmentObject(store))
            window.center()
        }
        scheduleDashboardResize()
        dashboard?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowDidChangeScreen(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === dashboard else { return }
        scheduleDashboardResize()
    }

    private func scheduleDashboardResize() {
        guard !dashboardResizeScheduled else { return }
        dashboardResizeScheduled = true
        // Wait until SwiftUI has finished its current layout pass.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.dashboardResizeScheduled = false
            self.fitDashboardToContent()
        }
    }

    private func fitDashboardToContent() {
        guard let window = dashboard, dashboardContentHeight > 0,
              let screen = window.screen ?? NSScreen.main else { return }
        let available = screen.visibleFrame
        let titlebarHeight = window.frame.height - window.contentLayoutRect.height
        var frame = window.frame
        let height = min(ceil(dashboardContentHeight + titlebarHeight), available.height)
        frame.origin.y = frame.maxY - height
        frame.size = NSSize(width: min(dashboardWidth, available.width), height: height)
        frame.origin.x = max(available.minX, min(frame.minX, available.maxX - frame.width))
        frame.origin.y = max(available.minY, min(frame.minY, available.maxY - frame.height))
        guard abs(frame.width - window.frame.width) > 0.5 || abs(frame.height - window.frame.height) > 0.5 || frame.origin != window.frame.origin else { return }
        if window.isVisible && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = AppMotion.duration
                context.timingFunction = AppMotion.timingFunction
                window.animator().setFrame(frame, display: true)
            }
        } else {
            window.setFrame(frame, display: true)
        }
    }
}

@main
struct WindowOrganizerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuContents(store: delegate.store, openDashboard: delegate.showDashboard, updateLayout: delegate.confirmLayoutUpdate)
        } label: {
            Image(nsImage: Brand.menuBarIcon)
                .accessibilityLabel("Window Organizer")
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Settings…", action: delegate.showSettings).keyboardShortcut(",")
                Divider()
                Button("Layout Details…") {
                    delegate.showDashboard()
                    NotificationCenter.default.post(name: Notification.Name("ShowLayoutDetails"), object: nil)
                }
                Button("Open Layout Data Folder", action: delegate.store.openDataFolder)
                Button("Accessibility Settings", action: WindowService.requestPermission)
            }
        }
    }
}

struct MenuContents: View {
    @ObservedObject var store: AppStore
    let openDashboard: () -> Void
    let updateLayout: (Layout) -> Void
    var body: some View {
        Button("Open Window Organizer", action: openDashboard).keyboardShortcut("o")
        Divider()
        if store.preferences.layouts.isEmpty { Text("Save your first layout in the dashboard") }
        ForEach(store.preferences.layouts) { layout in
            if layout.id != store.preferences.layouts.first?.id { Divider() }
            Button("Restore \(layout.name) layout") { store.apply(layout) }.disabled(store.busy || !store.hasPermission)
            Button("Update \(layout.name) layout") { updateLayout(layout) }.disabled(store.busy || !store.hasPermission)
        }
        Divider()
        Button("Undo Last Layout Change", action: store.undo).disabled(store.undoLayout == nil || store.busy || !store.hasPermission)
        Toggle("Automatic Switching", isOn: Binding(get: { store.preferences.autoSwitch }, set: store.setAutomatic))
        Divider()
        Button("Quit Window Organizer") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}
