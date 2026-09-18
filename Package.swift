// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Syllabreak",
  platforms: [
    .iOS(.v15),
    .macOS(.v12),
  ],
  products: [
    .library(
      name: "Syllabreak",
      targets: ["Syllabreak"])
  ],
  dependencies: [
    .package(url: "https://github.com/botforge-pro/swift-embed", from: "1.5.0"),
    .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.3.0"),
  ],
  targets: [
    .target(
      name: "Syllabreak",
      dependencies: [
        .product(name: "SwiftEmbed", package: "swift-embed")
      ],
      resources: [.process("Resources")]),
    .testTarget(
      name: "SyllabreakTests",
      dependencies: [
        "Syllabreak",
        .product(name: "SwiftEmbed", package: "swift-embed"),
      ],
      resources: [.process("Resources")]),
  ]
)
