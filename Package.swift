// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "CodexPulse",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .executable(name: "CodexPulse", targets: ["CodexPulse"])
  ],
  targets: [
    .executableTarget(
      name: "CodexPulse",
      path: "AppSources/CodexPulse"
    ),
    .testTarget(
      name: "CodexPulseTests",
      dependencies: ["CodexPulse"],
      path: "Tests/CodexPulseTests"
    ),
  ]
)
