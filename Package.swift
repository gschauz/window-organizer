// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WindowOrganizer",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "WindowOrganizer", targets: ["WindowOrganizer"])],
    targets: [
        .target(name: "SpaceBridge", cSettings: [.unsafeFlags(["-fobjc-arc"])]),
        .executableTarget(name: "WindowOrganizer", dependencies: ["SpaceBridge"], resources: [.copy("Assets")]),
        .testTarget(name: "WindowOrganizerTests", dependencies: ["WindowOrganizer"])
    ]
)
