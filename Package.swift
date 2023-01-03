// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "ApiFeatures",
  platforms: [
    .iOS(.v15),
    .macOS(.v12),
  ],
  
  products: [
    .library(name: "FlexErrors", targets: ["FlexErrors"]),
    .library(name: "Listener", targets: ["Listener"]),
    .library(name: "Objects", targets: ["Objects"]),
    .library(name: "Tcp", targets: ["Tcp"]),
    .library(name: "Udp", targets: ["Udp"]),
  ],
  
  dependencies: [
    .package(url: "https://github.com/robbiehanson/CocoaAsyncSocket", from: "7.6.5"),
    .package(url: "https://github.com/auth0/JWTDecode.swift", from: "2.6.0"),
    .package(url: "https://github.com/K3TZR/SharedFeatures.git", from: "1.6.1"),
    .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "0.42.0"),
  ],
  
  targets: [
    // --------------- Modules ---------------
    
    // FlexErrors
    .target(name: "FlexErrors",dependencies: [
      .product(name: "Shared", package: "SharedFeatures"),
    ]),
    
    // Listener
    .target(name: "Listener",dependencies: [
      .product(name: "CocoaAsyncSocket", package: "CocoaAsyncSocket"),
      .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      .product(name: "JWTDecode", package: "JWTDecode.swift"),
      .product(name: "Shared", package: "SharedFeatures"),
    ]),
    
    // Objects
    .target(name: "Objects",dependencies: [
      .product(name: "Shared", package: "SharedFeatures"),
      .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      "FlexErrors",
      "Listener",
      "Tcp",
      "Udp",
    ]),
    
    // Tcp
    .target(name: "Tcp",dependencies: [
      .product(name: "CocoaAsyncSocket", package: "CocoaAsyncSocket"),
      .product(name: "Shared", package: "SharedFeatures"),
    ]),
    
    // Udp
    .target(name: "Udp",dependencies: [
      .product(name: "CocoaAsyncSocket", package: "CocoaAsyncSocket"),
      .product(name: "Shared", package: "SharedFeatures"),
    ]),

    .testTarget(
        name: "ApiFeaturesTests", dependencies: [
          "Listener"
        ]),
  ]
)

