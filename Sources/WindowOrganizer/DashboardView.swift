import SwiftUI
import AppKit

private let ink = Theme.text
private let accent = Theme.icon
private let paper = Theme.canvas

struct DashboardView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var onContentHeightChange: (CGFloat) -> Void = { _ in }
    @State private var showingSave = false
    @State private var editingPresetID: UUID?
    @State private var renameDraft = ""
    @State private var collapsedPresets: Set<UUID> = []
    @State private var initializedCards = false
    @State private var pendingDeleteID: UUID?
    @State private var pendingUpdateID: UUID?
    @FocusState private var focusedPresetID: UUID?
    @State private var showingDelete = false
    @State private var showingUpdate = false
    @State private var showDetails = false
    @State private var name = ""
    @State private var hoveredDeleteID: UUID?
    @State private var expandedWindowLists: Set<UUID> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header.padding(.horizontal, 30).padding(.vertical, 24)
                VStack(alignment: .leading, spacing: 22) {
                    if !store.hasPermission { permissionCard }
                    if store.preferences.layouts.isEmpty { emptyState }
                    ForEach(store.preferences.layouts) { layout in layoutDetail(layout) }
                }.padding(.horizontal, 30).padding(.bottom, 30)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .background(GeometryReader { geometry in
                Color.clear.preference(key: DashboardHeightKey.self, value: geometry.size.height)
            })
        }
        .onAppear {
            guard !initializedCards else { return }
            collapsedPresets = Set(store.preferences.layouts.map(\.id))
            initializedCards = true
        }
        .onPreferenceChange(DashboardHeightKey.self, perform: onContentHeightChange)
        .background(WindowBackdrop())
        .foregroundColor(ink)
        .tint(Theme.control)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingSave) { nameSheet(title: "New Layout", subtitle: "Arrange your windows first. We’ll remember their sizes and positions.", actionTitle: "Save layout") { store.save(name: name) } }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowLayoutDetails"))) { _ in showDetails = true }
        .sheet(isPresented: $showDetails) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Layout details").font(.title2.bold())
                Text(store.message).font(.headline)
                ScrollView { VStack(alignment: .leading, spacing: 12) { ForEach(Array(store.details.enumerated()), id: \.offset) { _, note in Text(note).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) } } }
                Button("Done") { showDetails = false }.buttonStyle(.borderedProminent).clickCursor().frame(maxWidth: .infinity, alignment: .trailing)
            }.padding(28).frame(width: 560, height: 400)
                .background(Theme.card).foregroundColor(Theme.text).preferredColorScheme(.dark)
        }
        .alert("Delete this layout?", isPresented: $showingDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let id = pendingDeleteID {
                    store.delete(id)
                    collapsedPresets.remove(id)
                    if editingPresetID == id { cancelRename() }
                }
            }
        } message: { Text("Your open windows will stay where they are.") }
        .alert("Replace this saved layout?", isPresented: $showingUpdate) {
            Button("Cancel", role: .cancel) {}
            Button("Update layout") {
                if let layout = store.preferences.layouts.first(where: { $0.id == pendingUpdateID }) {
                    store.save(name: layout.name, replacing: layout.id)
                }
            }
        } message: { Text("Replace this layout with the current window positions and connected displays.") }
    }

    private var header: some View {
        HStack(spacing: 16) {
            HStack(spacing: 11) {
                Image(nsImage: Brand.mark)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 32, height: 30)
                    .accessibilityHidden(true)
                Text("Window Organizer")
                    .font(.system(size: 20, weight: .semibold))
            }.accessibilityElement(children: .combine)
            Spacer()
            if store.busy {
                ProgressView().controlSize(.small)
                    .help(store.message)
            }
            Button(action: startSave) {
                Label("New Layout", systemImage: "plus")
                    .padding(.horizontal, 3).padding(.vertical, 5)
            }
            .buttonStyle(.borderedProminent).clickCursor()
            .disabled(!store.hasPermission || store.busy)
        }
    }

    private var permissionCard: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "hand.raised.fill").font(.system(size: 23)).foregroundColor(accent).padding(.top, 3)
            VStack(alignment: .leading, spacing: 8) {
                Text("Allow window access").font(.system(size: 15, weight: .semibold))
                Text("Allow Window Organizer in System Settings → Privacy & Security → Accessibility so it can read, move, and resize your windows.").font(.system(size: 12)).foregroundColor(Theme.secondaryText).fixedSize(horizontal: false, vertical: true)
                Button("Enable Accessibility", action: WindowService.requestPermission).buttonStyle(.borderedProminent).clickCursor().padding(.top, 3)
                Text("Layouts stay on this Mac. No account or cloud service.").font(.system(size: 10)).foregroundColor(Theme.secondaryText)
            }
            Spacer(minLength: 0)
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(Theme.card).cornerRadius(14)
    }

    private var emptyState: some View {
        VStack(spacing: 17) {
            EmptyWorkspaceIllustration().frame(height: 106).padding(.top, 8)
            Text("Make yourself at home.").font(.system(size: 21, weight: .semibold))
            Text("Arrange your open windows just the way you like them,\nthen save your first layout. Try “Desk” or “Laptop.”")
                .font(.system(size: 13)).foregroundColor(Theme.secondaryText).multilineTextAlignment(.center).lineSpacing(4)
            Button("Save my first layout", action: startSave).buttonStyle(.borderedProminent).clickCursor().controlSize(.large).disabled(!store.hasPermission || store.busy)
            Text("Open windows · Positions & sizes · Display placement").font(.system(size: 10)).foregroundColor(Theme.secondaryText)
        }.padding(24).frame(maxWidth: .infinity).background(Theme.card).cornerRadius(16)
    }

    private func layoutDetail(_ layout: Layout) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        if editingPresetID == layout.id {
                            TextField("Layout name", text: $renameDraft)
                                .font(.system(size: 24, weight: .semibold))
                                .textFieldStyle(.plain)
                                .padding(.horizontal, 6).padding(.vertical, 3)
                                .background(paper)
                                .cornerRadius(5)
                                .frame(minWidth: 120, maxWidth: 360)
                                .focused($focusedPresetID, equals: layout.id)
                                .onAppear {
                                    DispatchQueue.main.async { focusedPresetID = layout.id }
                                }
                                .onSubmit { commitRename(layout.id) }
                                .onExitCommand(perform: cancelRename)
                                .accessibilityLabel("Layout name")
                                .help("Press Enter to save. Press Escape to cancel.")
                        } else {
                            Text(layout.name).font(.system(size: 24, weight: .semibold)).lineLimit(1)
                                .contentShape(Rectangle())
                                .onTapGesture(count: 2) { beginRenaming(layout) }
                                .clickCursor(enabled: !store.busy)
                                .accessibilityAction(named: Text("Rename layout")) { beginRenaming(layout) }
                                .help("Double-click to rename this layout.")
                        }
                    }
                    Text(layout.summary)
                        .font(.system(size: 11)).foregroundColor(Theme.secondaryText)
                }
                Spacer(minLength: 8)
                if collapsedPresets.contains(layout.id) {
                    Button("Restore layout") { store.apply(layout) }
                        .buttonStyle(LayoutActionButtonStyle(prominent: true))
                        .clickCursor()
                        .disabled(!store.hasPermission || store.busy)
                        .accessibilityLabel("Restore \(layout.name) layout")
                }
                Button {
                    if collapsedPresets.contains(layout.id) { collapsedPresets.remove(layout.id) }
                    else { collapsedPresets.insert(layout.id) }
                } label: {
                    Image(systemName: collapsedPresets.contains(layout.id) ? "chevron.right" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain).clickCursor()
                .foregroundColor(accent)
                .accessibilityLabel("\(collapsedPresets.contains(layout.id) ? "Expand" : "Collapse") \(layout.name)")
                .help(collapsedPresets.contains(layout.id) ? "Expand layout" : "Collapse layout")
            }
            if !collapsedPresets.contains(layout.id) { layoutBody(layout) }
        }
        .padding(22).background(Theme.card).cornerRadius(16)
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture {
            if collapsedPresets.contains(layout.id) { collapsedPresets.remove(layout.id) }
        }
        .clickCursor(enabled: collapsedPresets.contains(layout.id))
        .animation(reduceMotion ? nil : AppMotion.standard, value: collapsedPresets.contains(layout.id))
    }

    private func deleteControls(_ layout: Layout) -> some View {
        HStack(spacing: 8) {
                Text("Delete Layout")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.secondaryText)
                    .opacity(hoveredDeleteID == layout.id && !store.busy ? 1 : 0)
                    .animation(reduceMotion ? nil : AppMotion.standard, value: hoveredDeleteID == layout.id && !store.busy)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                Button {
                    pendingDeleteID = layout.id
                    showingDelete = true
                } label: {
                    DeleteBin(progress: hoveredDeleteID == layout.id && !store.busy ? 1 : 0)
                        .fill(accent)
                        .frame(width: 24, height: 24)
                        .clipped()
                        .animation(reduceMotion ? nil : AppMotion.standard, value: hoveredDeleteID == layout.id && !store.busy)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                        .accessibilityHidden(true)
                }
                .buttonStyle(.plain).clickCursor()
                .foregroundColor(accent)
                .disabled(store.busy)
                .accessibilityLabel("Delete \(layout.name)")
                .onHover { hovering in
                    if hovering && !store.busy { hoveredDeleteID = layout.id }
                    else if hoveredDeleteID == layout.id { hoveredDeleteID = nil }
                }
        }
        .onDisappear {
            if hoveredDeleteID == layout.id { hoveredDeleteID = nil }
        }
    }

    private func layoutBody(_ layout: Layout) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Group {
                if layout.displays.contains(where: { $0.spaces != nil }) { SpacesLayoutPreview(layout: layout) }
                else { LayoutPreview(layout: layout) }
            }
                .frame(height: 220)
                .padding(.vertical, 24)
                .background(paper)
                .cornerRadius(12)
            if layout.signature != store.currentSignature {
                Label("Different displays connected. Missing screens will map to your main display.", systemImage: "info.circle")
                    .font(.system(size: 11)).foregroundColor(Theme.secondaryText)
            }
            HStack {
                Button("Restore layout") { store.apply(layout) }
                    .buttonStyle(LayoutActionButtonStyle(prominent: true)).clickCursor().disabled(!store.hasPermission || store.busy)
                Button("Update layout") { pendingUpdateID = layout.id; showingUpdate = true }
                    .buttonStyle(LayoutActionButtonStyle(prominent: false)).clickCursor().disabled(!store.hasPermission || store.busy)
                Spacer(minLength: 24)
                AutoApplyExplanation()
                Toggle("Auto Apply Layout", isOn: Binding(get: { store.preferences.assignments[layout.signature] == layout.id }, set: { store.assign(layout, enabled: $0) }))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(Color(nsColor: .systemGreen))
                    .controlSize(.small)
                    .clickCursor()
                    .disabled(store.busy)
            }
            Divider()
            DisclosureGroup("Included windows (\(layout.windows.count))", isExpanded: Binding(
                get: { expandedWindowLists.contains(layout.id) },
                set: { expanded in
                    if expanded { expandedWindowLists.insert(layout.id) }
                    else { expandedWindowLists.remove(layout.id) }
                }
            )) {
                VStack(spacing: 9) {
                    ForEach(layout.windows) { window in
                        HStack(spacing: 9) {
                            AppIcon(bundleID: window.bundleID)
                            Text(window.appName).font(.system(size: 11, weight: .medium)).frame(width: 95, alignment: .leading).lineLimit(1)
                            Text(window.title.isEmpty ? "Untitled window" : window.title).font(.system(size: 11)).foregroundColor(Theme.secondaryText).lineLimit(1)
                            Spacer()
                            if let index = layout.desktopIndex(for: window) {
                                Text("Desktop \(index)").font(.system(size: 10)).foregroundColor(Theme.secondaryText)
                            }
                        }
                    }
                }.padding(.top, 12)
            }
            .disclosureGroupStyle(ClickableDisclosureStyle { deleteControls(layout) })
            .font(.system(size: 11)).foregroundColor(Theme.secondaryText)
            .animation(reduceMotion ? nil : AppMotion.standard, value: expandedWindowLists.contains(layout.id))
        }
    }

    private func beginRenaming(_ layout: Layout) {
        guard !store.busy else { return }
        renameDraft = layout.name
        editingPresetID = layout.id
    }

    private func commitRename(_ id: UUID) {
        guard !renameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        store.rename(id, to: renameDraft)
        cancelRename()
    }

    private func cancelRename() {
        focusedPresetID = nil
        editingPresetID = nil
        renameDraft = ""
    }

    private func sectionLabel(_ title: String) -> some View { Text(title).font(.system(size: 10, weight: .semibold)).tracking(1.5).foregroundColor(Theme.secondaryText) }
    private func startSave() {
        name = store.displays.count == 1 && store.displays.first?.builtIn == true ? "Laptop" : "Desk"
        showingSave = true
    }
    private func nameSheet(title: String, subtitle: String, actionTitle: String, action: @escaping () -> Void) -> some View {
        NameEditor(name: $name, title: title, subtitle: subtitle, actionTitle: actionTitle,
                   cancel: { showingSave = false },
                   save: { finishName(action) })
    }
    private func finishName(_ action: () -> Void) {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        action(); showingSave = false
    }
}

private struct DashboardHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct LayoutActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    let prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .frame(width: 156, height: 36)
            .foregroundColor(prominent ? .white : ink)
            .background(prominent ? Theme.control : Theme.secondaryControl)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(prominent ? Color.clear : ink.opacity(0.16), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 7))
            .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.45)
    }
}

private struct NameEditor: View {
    @Binding var name: String
    let title: String
    let subtitle: String
    let actionTitle: String
    let cancel: () -> Void
    let save: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title).font(.system(size: 23, weight: .semibold))
            Text(subtitle).font(.system(size: 13)).foregroundColor(Theme.secondaryText)
            TextField("Layout name", text: $name).textFieldStyle(.roundedBorder).onSubmit { if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { save() } }
            Text("Window titles and document paths are saved locally to help identify your windows.").font(.system(size: 11)).foregroundColor(Theme.secondaryText)
            HStack { Spacer(); Button("Cancel", action: cancel).clickCursor().keyboardShortcut(.cancelAction)
                Button(actionTitle, action: save).buttonStyle(.borderedProminent).clickCursor().keyboardShortcut(.defaultAction).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(30).frame(width: 450)
            .background(Theme.card).foregroundColor(Theme.text).tint(Theme.control).preferredColorScheme(.dark)
    }
}

struct AppIcon: View {
    let bundleID: String
    var body: some View {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 20, height: 20)
        } else { Image(systemName: "app").frame(width: 20, height: 20) }
    }
}

struct EmptyWorkspaceIllustration: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            mockScreen(width: 110, height: 72)
            mockScreen(width: 140, height: 92)
            mockScreen(width: 80, height: 55)
        }
    }
    private func mockScreen(width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 3).fill(accent.opacity(0.22)).frame(width: width * 0.35)
                VStack(spacing: 4) { RoundedRectangle(cornerRadius: 3).fill(accent.opacity(0.45)); RoundedRectangle(cornerRadius: 3).fill(accent.opacity(0.13)) }
            }.padding(7).frame(width: width, height: height).background(paper).overlay(RoundedRectangle(cornerRadius: 7).stroke(accent.opacity(0.4), lineWidth: 2)).cornerRadius(7)
            RoundedRectangle(cornerRadius: 2).fill(accent.opacity(0.25)).frame(width: width * 0.3, height: 4)
        }
    }
}

struct LayoutPreview: View {
    let layout: Layout
    private let colors: [Color] = [Color(white: 0.58), Color(white: 0.72), Color(white: 0.46), Color(white: 0.85)]
    var body: some View {
        GeometryReader { proxy in
            let union = layout.displays.reduce(CGRect.null) { $0.union($1.frame.rect) }
            let scale = max(0, min((proxy.size.width - 40) / max(1, union.width), (proxy.size.height - 64) / max(1, union.height)))
            let offsetX = (proxy.size.width - union.width * scale) / 2
            let offsetY = (proxy.size.height - 24 - union.height * scale) / 2
            ZStack(alignment: .topLeading) {
                ForEach(layout.displays) { display in
                    RoundedRectangle(cornerRadius: 6).fill(Theme.card).overlay(RoundedRectangle(cornerRadius: 6).stroke(accent.opacity(0.25), lineWidth: 2))
                        .frame(width: display.frame.width * scale, height: display.frame.height * scale)
                        .offset(x: offsetX + (display.frame.x - union.minX) * scale, y: offsetY + (display.frame.y - union.minY) * scale)
                }
                ForEach(Array(layout.windows.enumerated()), id: \.element.id) { index, window in
                    let r = window.frame.rect
                    RoundedRectangle(cornerRadius: 3).fill(colors[index % colors.count].opacity(0.28))
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(colors[index % colors.count].opacity(0.6), lineWidth: 1))
                        .overlay(alignment: .topLeading) { Text(window.appName).font(.system(size: 8, weight: .medium)).lineLimit(1).padding(4) }
                        .frame(width: max(1, r.width * scale - 2), height: max(1, r.height * scale - 2))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .offset(x: offsetX + (r.minX - union.minX) * scale + 1, y: offsetY + (r.minY - union.minY) * scale + 1)
                }
                ForEach(layout.displays) { display in
                    Label(display.name, systemImage: display.builtIn ? "laptopcomputer" : "display")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Theme.secondaryText)
                        .lineLimit(1)
                        .frame(width: display.frame.width * scale, height: 18)
                        .offset(x: offsetX + (display.frame.x - union.minX) * scale,
                                y: offsetY + (display.frame.y + display.frame.height - union.minY) * scale + 5)
                }
            }
            // Offsets don't expand a ZStack's layout bounds. Size the canvas to the
            // whole preview before clipping, or most of the monitor map disappears.
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .clipped()
        }.accessibilityElement(children: .ignore).accessibilityLabel("Preview of \(layout.name): \(layout.windows.count) windows across \(layout.displays.count) displays")
    }
}

/// An immediate, non-interactive callout so hovering never moves keyboard focus.
private struct AutoApplyExplanation: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showHelp = false
    private let explanation = "Automatically restore this layout when these monitors connect. Turn on Automatic Switching in Settings to enable this."

    var body: some View {
        HStack(spacing: 8) {
            Button { showHelp = true } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.secondaryText)
                    .frame(width: 20, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain).clickCursor()
            .accessibilityLabel("About Auto Apply Layout")
            .accessibilityHint(explanation)
            Text("Auto Apply Layout").font(.system(size: 12, weight: .medium))
        }
        .contentShape(Rectangle())
        .onHover { showHelp = $0 }
        .onDisappear { showHelp = false }
        .overlay(alignment: .bottomTrailing) {
            if showHelp {
                Text(explanation)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(12)
                    .frame(width: 270, alignment: .leading)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.18), lineWidth: 1))
                    .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
                    .offset(y: -34)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : AppMotion.standard, value: showHelp)
    }
}
