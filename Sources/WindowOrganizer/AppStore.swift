import AppKit
import SwiftUI
import ServiceManagement

final class AppStore: ObservableObject {
    @Published var preferences = Preferences()
    @Published var displays: [Display] = []
    @Published var hasPermission = WindowService.trusted
    @Published var busy = false
    @Published var message = "Your layout is ready."
    @Published var details: [String] = []
    @Published var selectedID: UUID?
    @Published var undoLayout: Layout?
    @Published var loginEnabled = SMAppService.mainApp.status == .enabled
    private let worker = DispatchQueue(label: "local.windoworganizer.accessibility", qos: .userInitiated)
    private var observers: [NSObjectProtocol] = []
    private var permissionTimer: Timer?
    private var pendingDisplayChange: DispatchWorkItem?
    private var storageReadable = true
    private var knownSignature = ""
    private let fileURL: URL

    var currentSignature: String { Geometry.signature(displays) }
    var selectedLayout: Layout? { preferences.layouts.first { $0.id == selectedID } }
    var assignedLayout: Layout? { preferences.layouts.first { $0.id == preferences.assignments[currentSignature] } }

    init() {
        fileURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WindowOrganizer/presets.json")
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                preferences = try JSONDecoder().decode(Preferences.self, from: Data(contentsOf: fileURL))
                if preferences.version != 1 { throw CocoaError(.fileReadCorruptFile) }
            }
        } catch {
            storageReadable = false
            message = "Saved layouts could not be loaded. The original file has been preserved."
            details = [error.localizedDescription, fileURL.path]
        }
        displays = WindowService.displays()
        knownSignature = currentSignature
        selectedID = preferences.layouts.first?.id
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in self?.scheduleDisplayCheck() })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in self?.scheduleDisplayCheck(force: true) })
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.hasPermission = WindowService.trusted
        }
    }

    private func persist() {
        guard storageReadable else {
            message = "Cannot save over an unreadable layouts file. Open the data folder to recover it."
            return
        }
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(preferences).write(to: fileURL, options: .atomic)
        } catch { message = "Could not save layouts to disk."; details = [error.localizedDescription] }
    }

    func save(name: String, replacing: UUID? = nil) {
        guard !busy, hasPermission else { return }
        let cleanName = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        guard !cleanName.isEmpty else { return }
        let screens = WindowService.displays()
        busy = true
        message = "Reading windows across your desktops…"
        details = []
        worker.async {
            let capture = WindowService.capture(displays: screens)
            DispatchQueue.main.async {
                self.busy = false
                guard Geometry.signature(WindowService.displays()) == Geometry.signature(screens) else {
                    self.message = "Your displays changed while saving. Please save again."; return
                }
                self.details = capture.notes
                guard capture.complete else {
                    self.message = "Could not read every desktop. Your saved layout has not been replaced."; return
                }
                guard !capture.windows.isEmpty else {
                    self.message = "No movable windows found. Open a normal app window and try again."; return
                }
                var layout = Layout(name: cleanName, displays: capture.displays, windows: capture.windows.map(\.saved))
                if let id = replacing, let index = self.preferences.layouts.firstIndex(where: { $0.id == id }) {
                    layout.id = id
                    self.preferences.assignments = self.preferences.assignments.filter { $0.value != id || $0.key == layout.signature }
                    self.preferences.layouts[index] = layout
                } else { self.preferences.layouts.append(layout) }
                self.selectedID = layout.id
                self.message = "Saved \(layout.windows.count) windows to \(cleanName)."
                self.persist()
            }
        }
    }

    func apply(_ layout: Layout, automatic: Bool = false, isUndo: Bool = false) {
        guard !busy else { return }
        hasPermission = WindowService.trusted
        guard hasPermission else { message = "Enable Accessibility to restore your windows."; return }
        let screens = WindowService.displays()
        guard !automatic || Geometry.signature(screens) == layout.signature else { return }
        busy = true
        details = []
        message = "Restoring \(layout.name)…"
        worker.async {
            let report = WindowService.restore(layout, displays: screens)
            DispatchQueue.main.async {
                self.busy = false
                self.undoLayout = isUndo ? nil : report.undo
                self.details = report.notes
                self.message = "\(isUndo ? "Undo complete" : "Restored " + layout.name) · \(report.moved) of \(layout.windows.count) windows positioned."
            }
        }
    }

    func undo() { if let layout = undoLayout { apply(layout, isUndo: true) } }

    func delete(_ id: UUID) {
        preferences.layouts.removeAll { $0.id == id }
        preferences.assignments = preferences.assignments.filter { $0.value != id }
        if selectedID == id { selectedID = preferences.layouts.first?.id }
        message = "Layout deleted."
        persist()
    }

    func rename(_ id: UUID, to name: String) {
        let clean = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        guard !clean.isEmpty, let i = preferences.layouts.firstIndex(where: { $0.id == id }) else { return }
        preferences.layouts[i].name = clean
        persist()
    }

    func setAutomatic(_ value: Bool) { preferences.autoSwitch = value; persist() }

    func assign(_ layout: Layout, enabled: Bool) {
        if enabled { preferences.assignments[layout.signature] = layout.id }
        else if preferences.assignments[layout.signature] == layout.id { preferences.assignments.removeValue(forKey: layout.signature) }
        persist()
    }

    func setLogin(_ value: Bool) {
        do {
            if value { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            loginEnabled = SMAppService.mainApp.status == .enabled
            if SMAppService.mainApp.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
        } catch { message = "Could not change Open at Login."; details = [error.localizedDescription] }
    }

    func openDataFolder() { NSWorkspace.shared.open(fileURL.deletingLastPathComponent()) }

    private func scheduleDisplayCheck(force: Bool = false) {
        pendingDisplayChange?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.displays = WindowService.displays()
            if self.busy { self.scheduleDisplayCheck(force: force); return }
            let changed = self.knownSignature != self.currentSignature
            self.knownSignature = self.currentSignature
            guard changed || force, self.preferences.autoSwitch else { return }
            guard let layout = self.assignedLayout else {
                self.message = "Connected displays changed. Choose a default layout for these displays to restore automatically."
                return
            }
            self.apply(layout, automatic: true)
        }
        pendingDisplayChange = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: work)
    }
}
