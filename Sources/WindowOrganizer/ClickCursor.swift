import AppKit
import SwiftUI

extension View {
    func clickCursor(enabled: Bool = true) -> some View {
        modifier(ClickCursorModifier(enabled: enabled))
    }
}

private struct ClickCursorModifier: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled
    @State private var ownsCursor = false
    let enabled: Bool

    private var active: Bool { enabled && isEnabled }

    func body(content: Content) -> some View {
        content
            .onContinuousHover { phase in
                switch phase {
                case .active:
                    guard active else { releaseCursor(); return }
                    if !ownsCursor {
                        NSCursor.pointingHand.push()
                        ownsCursor = true
                    }
                    // SwiftUI's hosting view can reset the cursor while moving
                    // within a control, so reapply it on every hover update.
                    NSCursor.pointingHand.set()
                case .ended:
                    releaseCursor()
                }
            }
            .onChange(of: active) { active in
                if !active { releaseCursor() }
            }
            .onDisappear { releaseCursor() }
    }

    private func releaseCursor() {
        guard ownsCursor else { return }
        ownsCursor = false
        NSCursor.pop()
    }
}

struct ClickableDisclosureStyle<Trailing: View>: DisclosureGroupStyle {
    let trailing: Trailing

    init(@ViewBuilder trailing: () -> Trailing) {
        self.trailing = trailing()
    }

    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Button { configuration.isExpanded.toggle() } label: {
                    HStack(spacing: 5) {
                        Image(systemName: configuration.isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                        configuration.label
                    }.contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .clickCursor()
                .accessibilityValue(configuration.isExpanded ? "Expanded" : "Collapsed")
                Spacer(minLength: 12)
                trailing
            }
            if configuration.isExpanded { configuration.content }
        }
    }
}
