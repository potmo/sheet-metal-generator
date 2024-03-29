// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(name: "sheet-metal-generator",
                      platforms: [
                          .macOS(.v14),
                      ],
                      dependencies: [
                          .package(name: "swift-canvas-renderer", path: "../../../swift-canvas-renderer"),
                      ],
                      targets: [
                          .executableTarget(name: "sheet-metal-generator",
                                            dependencies: [
                                                .product(name: "CanvasRender", package: "swift-canvas-renderer"),
                                            ]),

                      ])
