// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PersonalDashboard",
    defaultLocalization: "it",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "PersonalDashboard", targets: ["PersonalDashboard"]),
    ],
    targets: [
        .target(name: "DashboardCore"),
        .target(name: "DashboardServices", dependencies: ["DashboardCore"]),
        .executableTarget(name: "PersonalDashboard", dependencies: ["DashboardCore", "DashboardServices"]),
        .testTarget(name: "DashboardCoreTests", dependencies: ["DashboardCore"]),
        .testTarget(name: "DashboardServicesTests", dependencies: ["DashboardServices"]),
    ]
)
