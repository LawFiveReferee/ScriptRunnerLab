// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "ScriptRunnerKit",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .library(name: "ScriptRunnerKit", targets: ["ScriptRunnerKit"])
  ],
  targets: [
    .target(
      name: "ScriptRunnerKit",
      path: "Packages/ScriptRunnerKit/Sources/ScriptRunnerKit",
      resources: [
        .copy("Resources/CompatibilityTests")
      ],
      linkerSettings: [
        .linkedFramework("OSAKit")
      ]
    ),
    .testTarget(
      name: "ScriptRunnerKitTests",
      dependencies: ["ScriptRunnerKit"],
      path: "Packages/ScriptRunnerKit/Tests/ScriptRunnerKitTests"
    )
  ]
)
