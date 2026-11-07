import AppKit
let directory = URL(fileURLWithPath: CommandLine.arguments[1])
guard let mark = NSImage(contentsOfFile: CommandLine.arguments[2]) else {
    fatalError("The supplied app mark could not be loaded.")
}
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for factor in [1, 2] {
        let pixels = size * factor
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                      isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let scale = CGFloat(pixels) / 512
        let transform = NSAffineTransform()
        transform.scale(by: scale)
        transform.concat()
        // A soft white highlight fades into a light gray lower edge.
        let tile = NSBezierPath(roundedRect: NSRect(x: 28, y: 28, width: 456, height: 456), xRadius: 90, yRadius: 90)
        NSGraphicsContext.saveGraphicsState()
        tile.addClip()
        let context = NSGraphicsContext.current!.cgContext
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: [NSColor(white: 0.995, alpha: 1).cgColor,
                                           NSColor(white: 0.96, alpha: 1).cgColor,
                                           NSColor(white: 0.91, alpha: 1).cgColor] as CFArray,
                                  locations: [0, 0.48, 1])!
        context.drawRadialGradient(gradient,
                                   startCenter: CGPoint(x: 256, y: 484), startRadius: 0,
                                   endCenter: CGPoint(x: 256, y: 484), endRadius: 438,
                                   options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        NSGraphicsContext.restoreGraphicsState()
        // Vector geometry traced from the supplied 158 × 146 mark keeps every icon size crisp.
        let logoScale: CGFloat = 232.4 / 158
        let logoTransform = NSAffineTransform()
        logoTransform.translateX(by: (512 - 232.4) / 2, yBy: (512 - 146 * logoScale) / 2)
        logoTransform.scale(by: logoScale)
        logoTransform.concat()
        NSColor.black.setFill()
        for rect in [NSRect(x: 20, y: 82, width: 118, height: 64),
                     NSRect(x: 0, y: 22, width: 80, height: 52),
                     NSRect(x: 86, y: 0, width: 72, height: 74)] {
            NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8).fill()
        }
        NSGraphicsContext.restoreGraphicsState()
        let name = "icon_\(size)x\(size)\(factor == 2 ? "@2x" : "").png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(name))
    }
}
