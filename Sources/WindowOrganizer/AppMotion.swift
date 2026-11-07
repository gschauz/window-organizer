import SwiftUI
import QuartzCore

enum AppMotion {
    static let duration: TimeInterval = 0.24
    static let standard = Animation.timingCurve(0.5, 0, 0, 1, duration: duration)
    static let timingFunction = CAMediaTimingFunction(controlPoints: 0.5, 0, 0, 1)
}
