import SwiftUI
import AppKit

struct OrganizerSettingsView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Automation")
                .font(.system(size: 20, weight: .semibold))
            VStack(alignment: .leading, spacing: 18) {
                Toggle(isOn: Binding(get: { store.preferences.autoSwitch }, set: store.setAutomatic)) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Switch layouts when displays change")
                            .font(.system(size: 13, weight: .medium))
                        Text("Restores the default layout for the connected displays after connecting, disconnecting, or waking.")
                            .font(.system(size: 11)).foregroundColor(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }.clickCursor()
                Divider()
                Toggle("Open at login", isOn: Binding(get: { store.loginEnabled }, set: store.setLogin))
                    .font(.system(size: 13)).clickCursor()
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .padding(18)
            .background(Theme.card)
            .cornerRadius(12)
            Text("Saves normal windows across desktops. Missing desktops are recreated; extra desktops are kept. Desktop support is experimental. Full-screen and minimized windows aren’t included.")
                .font(.system(size: 11)).foregroundColor(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)
            VStack(alignment: .leading, spacing: 14) {
                Button("Open layout data folder", action: store.openDataFolder).clickCursor()
                Button("Accessibility settings", action: WindowService.requestPermission).clickCursor()
                Divider()
                Button("Quit Window Organizer") { NSApp.terminate(nil) }.clickCursor()
            }
            .buttonStyle(.borderless)
            .foregroundColor(Theme.text)
            .font(.system(size: 13))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Theme.card)
            .cornerRadius(12)
        }
        .padding(26)
        .frame(width: 510, height: 460)
        .background(WindowBackdrop())
        .foregroundColor(Theme.text)
        .tint(Theme.control)
        .preferredColorScheme(.dark)
    }
}
