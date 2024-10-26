// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "demo-syncronization",
  platforms: [.macOS(.v15)],
  products: [
    .library(
      name: "DemoSyncronization",
      targets: ["DemoSyncronization"])
  ],
  targets: [
    .target(
      name: "CXXFutex"),
    .target(
      name: "Futex",
      dependencies: ["CXXFutex"],
      swiftSettings: [.interoperabilityMode(.Cxx)]),
    .target(
      name: "DemoSyncronization",
      dependencies: ["Futex"],
      swiftSettings: [.interoperabilityMode(.Cxx)]),
    .testTarget(
      name: "DemoSyncronizationTests",
      dependencies: ["DemoSyncronization"],
      swiftSettings: [.interoperabilityMode(.Cxx)]
    ),
  ],
  cxxLanguageStandard: .cxx20
)
