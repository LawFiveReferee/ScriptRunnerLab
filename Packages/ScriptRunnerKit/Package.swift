// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "ScriptRunnerKit",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .library(name: "ScriptRunnerKit", targets: ["ScriptRunnerKit"])
  ],
  targets: [
    .target(
      name: "ScriptRunnerKit",
      resources: [
        .copy("Resources/CompatibilityTests")
      ],
      linkerSettings: [
        .linkedFramework("OSAKit")
      ]
    ),
    .testTarget(
      name: "ScriptRunnerKitTests",
      dependencies: ["ScriptRunnerKit"]
    )
  ]
)
