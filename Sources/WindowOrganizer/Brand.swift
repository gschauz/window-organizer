import AppKit

enum Brand {
    private static let resources: Bundle = {
        if Bundle.main.bundleURL.pathExtension == "app" {
            guard let url = Bundle.main.resourceURL?.appendingPathComponent("WindowOrganizer_WindowOrganizer.bundle"),
                  let bundle = Bundle(url: url) else {
                preconditionFailure("Missing packaged Window Organizer resources")
            }
            return bundle
        }
        return Bundle.module
    }()

    static let mark = loadMark("MarkWhite")

    static let menuBarIcon: NSImage = {
        let image = loadMark("MarkBlack")
        image.size = NSSize(width: 18, height: 18 * 146 / 158)
        // The supplied image's alpha mask lets macOS choose the appropriate
        // foreground color for light, dark, and selected menu-bar states.
        image.isTemplate = true
        return image
    }()

    private static func loadMark(_ name: String) -> NSImage {
        guard let url = resources.url(forResource: name, withExtension: "png", subdirectory: "Assets"),
              let image = NSImage(contentsOf: url) else {
            preconditionFailure("Missing bundled brand asset: \(name)")
        }
        return image
    }
}
