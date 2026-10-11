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
                          .executable(name: "sheet-metal-golden", targets: ["sheet-metal-golden"]),
                      ],
                      dependencies: [
                          .package(name: "swift-canvas-renderer", path: "../../../../../coding/swift-canvas-renderer"),
                      ],
                      targets: [
                          .executableTarget(name: "sheet-metal-generator-exec",
                                            dependencies: [
                                                .target(name: "sheet-metal-generator-lib"),
                                            ],
                                            resources: [
                                                .copy("Resources/normals.json"),
                                                .copy("Resources/mini-normals.json"),
                                            ]),
                          .target(name: "sheet-metal-generator-lib",
                                  dependencies: [
                                      .product(name: "CanvasRender", package: "swift-canvas-renderer"),
                                  ]),
                          // Headless golden-output CLI (see golden.sh). Mirrors every output path of the app.
                          .executableTarget(name: "sheet-metal-golden",
                                            dependencies: [
                                                .target(name: "sheet-metal-generator-lib"),
                                                .product(name: "CanvasRender", package: "swift-canvas-renderer"),
                                            ],
                                            swiftSettings: [
                                                .swiftLanguageMode(.v5),
                                            ]),
                      ])
