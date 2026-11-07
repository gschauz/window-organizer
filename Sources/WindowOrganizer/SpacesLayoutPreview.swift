import SwiftUI

struct SpacesLayoutPreview: View {
    let layout: Layout
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selections: [String: UInt64] = [:]

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            ForEach(layout.displays.sorted { $0.frame.x < $1.frame.x }) { display in
                monitor(display)
                    .frame(maxWidth: 240, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 18)
    }

    private func monitor(_ display: Display) -> some View {
        let spaces = display.spaces?.filter { !$0.isFullscreen } ?? []
        let selected = spaces.first { $0.id == selections[display.id] }
            ?? spaces.first(where: \.isActive) ?? spaces.first
        let windows = windows(on: selected, display: display)
        return VStack(alignment: .leading, spacing: 10) {
            Label(display.name, systemImage: display.builtIn ? "laptopcomputer" : "display")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Theme.secondaryText)
                .lineLimit(1)
            DesktopCanvas(display: display, windows: windows, showsTitles: true)
                .frame(height: 112)
                .accessibilityLabel("\(display.name), Desktop \(selected?.index ?? 1), \(windows.count) windows")
            HStack(spacing: 5) {
                Text("Desktop \(selected?.index ?? 1)")
                    .font(.system(size: 11, weight: .medium))
                Spacer(minLength: 0)
                Text("\(windows.count) \(windows.count == 1 ? "window" : "windows")")
                    .font(.system(size: 10)).foregroundColor(Theme.secondaryText)
            }
            if spaces.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(spaces) { space in
                            Button { selections[display.id] = space.id } label: {
                                VStack(spacing: 4) {
                                    DesktopCanvas(display: display, windows: self.windows(on: space, display: display), showsTitles: false, isSelected: selected?.id == space.id)
                                        .frame(width: 40, height: 25)
                                    Text("\(space.index)").font(.system(size: 9, weight: selected?.id == space.id ? .semibold : .regular))
                                        .foregroundColor(selected?.id == space.id ? Theme.text : Theme.secondaryText)
                                }.padding(2).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain).clickCursor()
                            .accessibilityLabel("Preview \(display.name), Desktop \(space.index)")
                            .accessibilityAddTraits(selected?.id == space.id ? .isSelected : [])
                            .help("Preview Desktop \(space.index) · \(self.windows(on: space, display: display).count) windows. This does not switch your actual desktop.")
                        }
                    }
                }.frame(height: 45)
            } else {
                Text(spaces.isEmpty ? "Desktop not recorded" : "1 saved desktop")
                    .font(.system(size: 10)).foregroundColor(Theme.secondaryText)
                    .frame(height: 45, alignment: .topLeading)
            }
        }
        .animation(reduceMotion ? nil : AppMotion.standard, value: selections[display.id])
    }

    private func windows(on space: DesktopSpace?, display: Display) -> [SavedWindow] {
        layout.windows.filter { window in
            guard window.displayID == display.id else { return false }
            guard let space, let ids = window.spaceIDs, !ids.isEmpty else { return true }
            return ids.contains(space.id)
        }
    }
}

private struct DesktopCanvas: View {
    let display: Display
    let windows: [SavedWindow]
    let showsTitles: Bool
    var isSelected = false
    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / max(1, display.frame.width), proxy.size.height / max(1, display.frame.height))
            let screenWidth = max(1, display.frame.width) * scale
            let screenHeight = max(1, display.frame.height) * scale
            let cornerRadius: CGFloat = showsTitles ? 6 : 3
            ZStack(alignment: .topLeading) {
                ForEach(Array(windows.enumerated()), id: \.element.id) { index, window in
                    let rect = window.frame.rect.intersection(display.frame.rect)
                    if !rect.isNull && !rect.isEmpty {
                        RoundedRectangle(cornerRadius: showsTitles ? 2 : 1)
                            .fill(Color(white: 0.45 + Double(index % 4) * 0.1).opacity(0.55))
                            .overlay(RoundedRectangle(cornerRadius: 2).stroke(Theme.text.opacity(0.25), lineWidth: 0.5))
                            .overlay(alignment: .topLeading) {
                                if showsTitles {
                                    Text(window.appName).font(.system(size: 8, weight: .medium))
                                        .lineLimit(1).padding(3)
                                }
                            }
                            .frame(width: max(1, rect.width * scale - 1), height: max(1, rect.height * scale - 1))
                            .clipped()
                            .offset(x: (rect.minX - display.frame.x) * scale,
                                    y: (rect.minY - display.frame.y) * scale)
                    }
                }
            }
            // Keep the bezel and windows in the same scaled display rectangle.
            // The surrounding layout slot may be wider, but it is not part of the screen.
            .frame(width: screenWidth, height: screenHeight, alignment: .topLeading)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(isSelected ? Theme.text : Theme.icon.opacity(0.25), lineWidth: 1))
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
        }.accessibilityHidden(true)
    }
}
