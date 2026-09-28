// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Quadro",
    defaultLocalization: "it",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "Quadro", targets: ["Quadro"]),
    ],
    targets: [
        .target(name: "DashboardCore"),
        .target(name: "DashboardServices", dependencies: ["DashboardCore"]),
        .executableTarget(name: "Quadro", dependencies: ["DashboardCore", "DashboardServices"]),
        .testTarget(name: "DashboardCoreTests", dependencies: ["DashboardCore"]),
        .testTarget(name: "DashboardServicesTests", dependencies: ["DashboardServices"]),
    ]
)
