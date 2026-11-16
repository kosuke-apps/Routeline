// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Routeline",
  platforms: [.iOS(.v17), .macOS(.v14)],
  products: [
    .library(name: "RoutelineCore", targets: ["RoutelineCore"]),
    .executable(name: "feedanalysis", targets: ["feedanalysis"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.28.0"),
    .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.19"),
  ],
  targets: [
    .target(
      name: "RoutelineCore",
      dependencies: [
        .product(name: "SwiftProtobuf", package: "swift-protobuf"),
        .product(name: "ZIPFoundation", package: "ZIPFoundation"),
      ],
      swiftSettings: [.swiftLanguageMode(.v5)]
    ),
    .executableTarget(
      name: "feedanalysis",
      dependencies: ["RoutelineCore"],
      swiftSettings: [.swiftLanguageMode(.v5)]
    ),
    .testTarget(
      name: "FeedAnalysisTests",
      dependencies: ["feedanalysis", "RoutelineCore"],
      swiftSettings: [.swiftLanguageMode(.v5)]
    ),
    .testTarget(
      name: "RoutelineCoreTests",
      dependencies: ["RoutelineCore"],
      swiftSettings: [.swiftLanguageMode(.v5)]
    ),
  ]
)
