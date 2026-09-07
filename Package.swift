// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "WorktreeLauncher",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "WorktreeLauncherCore", targets: ["WorktreeLauncherCore"]),
        .library(name: "WorktreeLauncherCLI", targets: ["WorktreeLauncherCLI"]),
        .library(name: "WorktreeLauncherAppSupport", targets: ["WorktreeLauncherAppSupport"]),
        .executable(name: "WorktreeLauncherApp", targets: ["WorktreeLauncherApp"]),
        .executable(name: "wt-launch", targets: ["wt-launch"]),
    ],
    targets: [
        .target(name: "WorktreeLauncherCore"),
        .target(name: "WorktreeLauncherCLI", dependencies: ["WorktreeLauncherCore"]),
        .target(name: "WorktreeLauncherAppSupport", dependencies: ["WorktreeLauncherCore"]),
        .executableTarget(name: "WorktreeLauncherApp", dependencies: ["WorktreeLauncherAppSupport", "WorktreeLauncherCore"]),
        .executableTarget(name: "wt-launch", dependencies: ["WorktreeLauncherCLI", "WorktreeLauncherCore"]),
        .testTarget(name: "WorktreeLauncherCoreTests", dependencies: ["WorktreeLauncherCore"]),
        .testTarget(name: "WtLaunchTests", dependencies: ["WorktreeLauncherCLI", "WorktreeLauncherCore"]),
        .testTarget(name: "WorktreeLauncherAppTests", dependencies: ["WorktreeLauncherAppSupport", "WorktreeLauncherCore"]),
    ]
)
