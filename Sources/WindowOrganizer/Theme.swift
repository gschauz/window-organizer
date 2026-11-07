import SwiftUI
import AppKit

enum Theme {
    static let card = Color(.sRGB, red: 40.0 / 255, green: 40.0 / 255, blue: 40.0 / 255, opacity: 1)
    static let canvas = Color(white: 0.065)
    static let text = Color.white
    static let secondaryText = Color(white: 0.70)
    static let icon = Color(white: 0.85)
    static let control = Color(white: 0.32)
    static let secondaryControl = Color(white: 0.16)

    static func configure(_ window: NSWindow) {
        window.isOpaque = false
        window.backgroundColor = .clear
        window.appearance = NSAppearance(named: .darkAqua)
        window.styleMask.insert(.fullSizeContentView)
        window.titlebarAppearsTransparent = true
    }
}

/// Real behind-window translucency, with a black tint over the native blur.
struct WindowBackdrop: View {
    var body: some View {
        WindowBlur()
            .overlay(Color.black.opacity(0.65))
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }
}

private struct WindowBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.appearance = NSAppearance(named: .darkAqua)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
