// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(name: "sheet-metal-generator",
                      platforms: [
                          .macOS(.v14),
                      ],
                      products: [
                          .library(name: "sheet-metal-generator-lib", targets: ["sheet-metal-generator-lib"]),
                          .executable(name: "sheet-metal-generator-exec", targets: ["sheet-metal-generator-exec"]),
                      ],
                      dependencies: [
                          .package(name: "swift-canvas-renderer", path: "../../../swift-canvas-renderer"),
                      ],
                      targets: [
                          .executableTarget(name: "sheet-metal-generator-exec",
                                            dependencies: [
                                                .target(name: "sheet-metal-generator-lib"),
                                            ]),
                          .target(name: "sheet-metal-generator-lib",
                                  dependencies: [
                                      .product(name: "CanvasRender", package: "swift-canvas-renderer"),
                                  ]),

                      ])
