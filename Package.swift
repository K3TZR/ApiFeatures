// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "ApiFeatures",
  platforms: [.macOS(.v14),],
  
  products: [
    .library(name: "FlexApi", targets: ["FlexApi"]),
    .library(name: "FlexErrors", targets: ["FlexErrors"]),
    .library(name: "Listener", targets: ["Listener"]),
    .library(name: "Tcp", targets: ["Tcp"]),
    .library(name: "Udp", targets: ["Udp"]),
    .library(name: "Vita", targets: ["Vita"]),
  ],
  
  dependencies: [
    // ----- K3TZR -----
    .package(url: "https://github.com/K3TZR/CommonFeatures.git", branch: "main"),
    // ----- OTHER -----
    .package(url: "https://github.com/robbiehanson/CocoaAsyncSocket", from: "7.6.5"),
    .package(url: "https://github.com/auth0/JWTDecode.swift", from: "2.6.0"),
    .package(url: "https://github.com/pointfreeco/swift-identified-collections", from: "1.0.0"),
  ],
  
  targets: [
    // --------------- Modules ---------------
    // FlexApi
    .target(name: "FlexApi",dependencies: [
      "FlexErrors",
      "Listener",
      "Tcp",
      "Udp",
      "Vita",
      .product(name: "SettingsModel", package: "CommonFeatures"),
      .product(name: "SharedModel", package: "CommonFeatures"),
      .product(name: "IdentifiedCollections", package: "swift-identified-collections"),
    ]),
    
    // FlexErrors
    .target(name: "FlexErrors",dependencies: [
      .product(name: "SharedModel", package: "CommonFeatures"),
    ]),
    
    // Listener
    .target(name: "Listener",dependencies: [
      .product(name: "SharedModel", package: "CommonFeatures"),
      .product(name: "SettingsModel", package: "CommonFeatures"),
      .product(name: "CocoaAsyncSocket", package: "CocoaAsyncSocket"),
      .product(name: "IdentifiedCollections", package: "swift-identified-collections"),
      .product(name: "JWTDecode", package: "JWTDecode.swift"),
      "Vita",
    ]),
    
    // Tcp
    .target(name: "Tcp",dependencies: [
      .product(name: "SharedModel", package: "CommonFeatures"),
      .product(name: "CocoaAsyncSocket", package: "CocoaAsyncSocket"),
    ]),

    // Udp
    .target(name: "Udp",dependencies: [
      .product(name: "SharedModel", package: "CommonFeatures"),
      .product(name: "CocoaAsyncSocket", package: "CocoaAsyncSocket"),
    ]),

    // Vita
    .target(name: "Vita",dependencies: [
    ]),

    // --------------- Tests ---------------
    .testTarget(
        name: "ApiFeaturesTests", dependencies: [
          "Listener"
        ]),
  ]
)

