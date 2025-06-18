// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "appstoreconnect",
  platforms: [.macOS(.v13)],
  dependencies: [
    .package(url: "https://github.com/AvdLee/appstoreconnect-swift-sdk.git", .upToNextMajor(from: "3.7.1")),
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.1"),
  ],
  targets: [
    .executableTarget(
      name: "appstoreconnect",
      dependencies: [
        .product(name: "AppStoreConnect-Swift-SDK", package: "appstoreconnect-swift-sdk"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ]
    ),
  ]
)
