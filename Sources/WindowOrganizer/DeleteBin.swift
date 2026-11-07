import SwiftUI

/// Interpolates between the user's closed-bin and open-lid SVGs in a 24 × 24 view box.
struct DeleteBin: Shape {
    var progress: CGFloat = 0

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat, _ endX: CGFloat, _ endY: CGFloat) -> CGPoint {
            CGPoint(x: x + (endX - x) * progress, y: y + (endY - y) * progress)
        }
        var path = Path()
        // Lid and handle: these vertices follow the exact supplied tilted-lid SVG.
        path.move(to: point(9, 3, 7.82963, 1.84702))
        path.addLine(to: point(9, 4, 8.08845, 2.81294))
        path.addLine(to: point(4, 4, 3.25882, 4.10704))
        path.addLine(to: point(4, 6, 3.77646, 6.03889))
        path.addLine(to: point(20, 6, 19.2313, 1.89779))
        path.addLine(to: point(20, 4, 18.7136, -0.0340656))
        path.addLine(to: point(15, 4, 13.884, 1.26003))
        path.addLine(to: point(15, 3, 13.6252, 0.294104))
        path.closeSubpath()

        // Open-topped body, with its lower edge and slots moving down on hover.
        path.move(to: point(7, 6, 7, 7))
        path.addLine(to: point(7, 19, 7, 22))
        path.addLine(to: point(17, 19, 17, 22))
        path.addLine(to: point(17, 6, 17, 7))
        path.addLine(to: point(19, 6, 19, 7))
        path.addLine(to: point(19, 19, 19, 22))
        path.addCurve(to: point(18.4142, 20.4142, 18.4141, 23.4141),
                      control1: point(19, 19.5304, 19, 22.5304),
                      control2: point(18.7893, 20.0391, 18.7891, 23.039))
        path.addCurve(to: point(17, 21, 17, 24),
                      control1: point(18.0391, 20.7893, 18.039, 23.7891),
                      control2: point(17.5304, 21, 17.5304, 24))
        path.addLine(to: point(7, 21, 7, 24))
        path.addCurve(to: point(5.58579, 20.4142, 5.58594, 23.4141),
                      control1: point(6.46957, 21, 6.46957, 24),
                      control2: point(5.96086, 20.7893, 5.96101, 23.7891))
        path.addCurve(to: point(5, 19, 5, 22),
                      control1: point(5.21071, 20.0391, 5.21086, 23.039),
                      control2: point(5, 19.5304, 5, 22.5304))
        path.addLine(to: point(5, 6, 5, 7))
        path.addLine(to: point(7, 6, 7, 7))
        path.closeSubpath()

        for x: CGFloat in [9, 13] {
            path.move(to: point(x, 8, x, 11))
            path.addLine(to: point(x, 17, x, 20))
            path.addLine(to: point(x + 2, 17, x + 2, 20))
            path.addLine(to: point(x + 2, 8, x + 2, 11))
            path.closeSubpath()
        }
        return path.applying(CGAffineTransform(a: rect.width / 24, b: 0, c: 0, d: rect.height / 24, tx: rect.minX, ty: rect.minY))
    }
}
