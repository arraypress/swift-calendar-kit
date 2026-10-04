// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "swift-calendar-kit",
    platforms: [
        .macOS(.v14), .iOS(.v17), .tvOS(.v17), .watchOS(.v10), .visionOS(.v1),
    ],
    products: [
        .library(name: "CalendarCore", targets: ["CalendarCore"]),
        .library(name: "CalendarUI", targets: ["CalendarUI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/arraypress/swift-chrono-kit.git", from: "0.12.0"),
    ],
    targets: [
        .target(name: "CalendarCore", dependencies: [.product(name: "ChronoKit", package: "swift-chrono-kit")]),
        .target(name: "CalendarUI", dependencies: ["CalendarCore"]),
        .executableTarget(name: "CalendarDemo", dependencies: ["CalendarUI"]),
        .testTarget(name: "CalendarCoreTests", dependencies: ["CalendarCore"]),
    ]
)
