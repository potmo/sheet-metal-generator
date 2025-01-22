import AppKit
import CanvasRender
import sheet_metal_generator_lib
import simd
import SwiftUI

typealias Vector = simd_double3
typealias Quat = simd_quatd

@main
struct SheetMetalGenerator: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject var state = InputState()

    init() {
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
            // NSApp.windows.first?.isOpaque = false
            // NSApp.windows.first?.backgroundColor = .clear
        }
    }

    @ViewBuilder var options: some View {
        HStack {
            Button("SVG") {
                let svgTarget = SVGRenderTarget()
                let maker = FromSidesView()
                let staticCamera = StaticCamera(position: Vector(0, 0, 200),
                                                rotation: Quat(angle: 0,
                                                               axis: Vector(0, 0, 1)))

                let renderTransform = OrthographicTransform(camera: staticCamera)
                let context = RenderContext(canvasSize: Vector2D(1000, 1000),
                                            renderTarget: svgTarget,
                                            transform2d: CGAffineTransform(scaleX: 1 / (25.4 / 72), y: 1 / (25.4 / 72)), // pixels to millimeters
                                            transform3d: renderTransform)
                let shapes = maker.shapes(from: state)
                shapes.forEach { $0.draw(in: context) }

                let string = svgTarget.svg
                NSPasteboard.general.setString(string, forType: .string)
                print(string)
            }

            Button("DXF") {
                let dxfTarget = DXFRenderTarget()
                let maker = FromSidesView()

                let staticCamera = StaticCamera(position: Vector(0, 0, 200),
                                                rotation: Quat(angle: -.pi * 0.5, axis: Vector(1, 0, 0)))

                let renderTransform = OrthographicTransform(camera: staticCamera)
                let context = RenderContext(canvasSize: Vector2D(1000, 1000),
                                            renderTarget: dxfTarget,
                                            transform2d: CGAffineTransform(scaleX: 1, y: 1),
                                            transform3d: renderTransform)
                let shapes = maker.shapes(from: state)
                shapes.forEach { $0.draw(in: context) }

                let string = dxfTarget.dxf(pdfFileName: "generated.pdf", dxfFileName: "generated.dxf", includeHeader: true)
                print(string)
                NSPasteboard.general.prepareForNewContents()
                NSPasteboard.general.setString(string, forType: .string)
            }

            Button("Shell DXF all") {
                let normals = [
                    (0, 0, Vector(0.2673, 0.1397, 0.9534)),
                    (0, 1, Vector(0.2650, 0.1686, 0.9494)),
                    (0, 2, Vector(0.2625, 0.1971, 0.9446)),
                    (0, 3, Vector(0.2599, 0.2251, 0.9390)),
                    (0, 4, Vector(0.2571, 0.2528, 0.9327)),
                    (1, 0, Vector(0.0774, 0.1560, 0.9847)),
                    (1, 1, Vector(0.2369, 0.1709, 0.9564)),
                    (1, 2, Vector(0.0762, 0.2142, 0.9738)),
                    (1, 3, Vector(0.1307, 0.2393, 0.9621)),
                    (1, 4, Vector(0.0747, 0.2705, 0.9598)),
                    (2, 0, Vector(-0.1811, 0.1461, 0.9726)),
                    (2, 1, Vector(-0.0133, 0.1862, 0.9824)),
                    (2, 2, Vector(-0.1768, 0.2042, 0.9628)),
                    (2, 3, Vector(-0.0127, 0.2436, 0.9698)),
                    (2, 4, Vector(-0.1721, 0.2606, 0.9500)),
                    (3, 0, Vector(0.0136, 0.1568, 0.9875)),
                    (3, 1, Vector(0.0133, 0.1862, 0.9824)),
                    (3, 2, Vector(0.0130, 0.2152, 0.9765)),
                    (3, 3, Vector(0.1234, 0.2381, 0.9634)),
                    (3, 4, Vector(0.0125, 0.2715, 0.9624)),
                    (4, 0, Vector(0.1514, 0.1481, 0.9773)),
                    (4, 1, Vector(0.1494, 0.1775, 0.9727)),
                    (4, 2, Vector(0.1473, 0.2064, 0.9673)),
                    (4, 3, Vector(0.1451, 0.2349, 0.9611)),
                    (4, 4, Vector(0.1429, 0.2629, 0.9542)),
                ]
                Task {
                    for (x, y, normal) in normals {
                        let dxfTarget = DXFRenderTarget()
                        let maker = FromSidesView()

                        let state = state

                        state.firstLabel = "\(x)".leftpad(to: 3, with: "0") + " " + "\(y)".leftpad(to: 3, with: "0")
                        state.staticNormal = normal

                        let staticCamera = StaticCamera(position: Vector(0, 0, 200),
                                                        rotation: Quat(angle: -.pi * 0.5, axis: Vector(1, 0, 0)))

                        let renderTransform = OrthographicTransform(camera: staticCamera)
                        let context = RenderContext(canvasSize: Vector2D(1000, 1000),
                                                    renderTarget: dxfTarget,
                                                    transform2d: CGAffineTransform(scaleX: 1, y: 1),
                                                    transform3d: renderTransform)
                        let shapes = maker.shapes(from: state)
                        shapes.forEach { $0.draw(in: context) }


                        let string = dxfTarget.dxf(pdfFileName: "/Users/nissebergman/Documents/SyncedProjects/art/projects/sheet metal prism/test-files/tomtits/test-generation5x5/box_\(x)_\(y).pdf",
                                                   dxfFileName: "/Users/nissebergman/Documents/SyncedProjects/art/projects/sheet metal prism/test-files/tomtits/test-generation5x5/box_\(x)_\(y).dxf",
                                                   includeHeader: true)

                        do {
                            let program = string

                            let task = Process()
                            let pipe = Pipe()

                            task.standardOutput = pipe
                            task.standardError = pipe
                            task.arguments = ["-c", program]
                            task.executableURL = URL(fileURLWithPath: "/usr/local/bin/python3") // <--updated
                            task.standardInput = nil

                            try task.run()

                            let data = pipe.fileHandleForReading.readDataToEndOfFile()
                            let output = String(data: data, encoding: .utf8)!

                            print(output)
                            print("done \(x) \(y)")

                        } catch {
                            print("error \(error)")
                        }
                    }
                }
            }

            DoubleSlider(label: "Angle Slerp", value: $state.angleSlerp, range: 0.0 ... 1.0)
            Toggle(isOn: $state.showHorizontalFlatView) { Text("Horizontal") }
            Toggle(isOn: $state.showTopAlignedFlatView) { Text("Foldout") }
            Toggle(isOn: $state.showFolded) { Text("Folded") }
            Toggle(isOn: $state.show3dView) { Text("3D") }
            Toggle(isOn: $state.fullScreenTop) { Text("Single view") }
        }

        HStack {
            DoubleSlider(label: "Thickness", value: $state.thickness, range: 0.0 ... 5.0)
            DoubleSlider(label: "Bottom Thickness", value: $state.bottomPlateThickness, range: 0.0 ... 5.0)
            DoubleSlider(label: "Size", value: $state.size, range: 0.0 ... 150.0)
            DoubleSlider(label: "Height", value: $state.height, range: 0.0 ... 150.0)
        }

        HStack {
            DoubleSlider(label: "Fastener thickness", value: $state.fastenerThickness, range: 0.0 ... 5.0)
            DoubleSlider(label: "Fastener width", value: $state.fastenerWidth, range: 0.0 ... 20.0)
        }
        HStack {
            DoubleSlider(label: "Clearence", value: $state.holeClearence, range: 0.0 ... 1.0)
            DoubleSlider(label: "Gap scalar", value: $state.gapScalar, range: 1.0 ... 5.0)
        }

        HStack {
            DoubleSlider(label: "Inner radius", value: $state.bendRadius, range: 0.0 ... 10.0)
            DoubleSlider(label: "K-Factor", value: $state.kFactor, range: 0.0 ... 1.0)
        }

        HStack {
            DoubleSlider(label: "X-Angle", value: $state.angleAroundX, range: -60.0 ... 60.0)
            DoubleSlider(label: "Y-Angle", value: $state.angleAroundY, range: -60.0 ... 60.0)
        }

        HStack(spacing: 0) {
            DoubleSlider(label: "Orbit", value: $state.cameraOrbit, range: -180.0 ... 180.0)
            DoubleSlider(label: "Tilt", value: $state.cameraTilt, range: -180.0 ... 180.0)
            // DoubleSlider(label: "Side", value: $state.cameraDollySide, range: -100.0 ... 100.0)
            // DoubleSlider(label: "Up", value: $state.cameraDollyUp, range: -100.0 ... 100.0)
        }
    }

    @ViewBuilder var singleView: some View {
        VStack {
            self.options
        }
        VStack {
            if state.show3dView {
                CanvasView(state: state,
                           maker: FromSidesView(),
                           renderTransform: OrthographicTransform(camera: StateObjectCamera(state: state)))
            } else {
                CanvasView(state: state,
                           maker: FromSidesView(),
                           renderTransform: OrthographicTransform(camera: StaticCamera(position: Vector(0, 0, 20),
                                                                                       rotation: Quat(angle: -.pi * 0.5, axis: Vector(1, 0, 0)))))
            }
        }
    }

    @ViewBuilder var multiView: some View {
        VStack {
            self.options
        }

        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // CanvasView(state: state, maker: FlatView())
                // CanvasView(state: state, maker: FlatSideView(), renderTransform: AxisAlignedOrthographicTransform(plane: .xy))

                // Top view
                CanvasView(state: state,
                           maker: FromSidesView(),
                           renderTransform: OrthographicTransform(camera: StaticCamera(position: Vector(0, 0, 200),
                                                                                       rotation: Quat(angle: .pi / 2,
                                                                                                      axis: Vector(-1, 0, 0)))))

                let cameraOrbit = Quat(angle: 0, axis: Vector(0, 0, 1))
                let cameraTilt = Quat(angle: .pi / 2, axis: cameraOrbit.act(Vector(1, 0, 0)))

                // Front view
                CanvasView(state: state, maker: FromSidesView(),
                           renderTransform: OrthographicTransform(camera: StaticCamera(position: Vector(0, 0, 200),
                                                                                       rotation: cameraTilt * cameraOrbit)))
            }
            HStack(spacing: 0) {
                let cameraOrbit = Quat(angle: -.pi / 2, axis: Vector(0, 0, 1))
                let cameraTilt = Quat(angle: .pi / 2, axis: cameraOrbit.act(Vector(1, 0, 0)))

                // Left view
                CanvasView(state: state, maker: FromSidesView(),
                           renderTransform: OrthographicTransform(camera: StaticCamera(position: Vector(0, 0, 200),
                                                                                       rotation: cameraTilt * cameraOrbit)))

                // orbit view
                CanvasView(state: state, maker: FromSidesView(),
                           renderTransform: OrthographicTransform(camera: StateObjectCamera(state: state)))
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if state.fullScreenTop {
                    singleView
                } else {
                    multiView
                }
            }
            .background(.white)
        }
    }
}

private struct StaticCamera: PerspectiveCamera {
    let position: Vector
    let rotation: Quat

    init(position: Vector, rotation: Quat) {
        self.position = position
        self.rotation = rotation
    }

    init(position: Vector, lookDirection: Vector) {
        self.position = position
        self.rotation = Quat(from: Vector(1, 0, 0), to: lookDirection.normalized)
    }
}

private struct StateObjectCamera: PerspectiveCamera {
    private let state: InputState
    init(state: InputState) {
        self.state = state
    }

    var position: Vector {
        /*
         let matrix = matrix_identity_double4x4 *
             simd_double4x4(translate: simd_double3(x: state.cameraDollySide, y: -200, z: state.cameraDollyUp)) *
             simd_double4x4(pitch: state.cameraTilt.degreesToRadians, jaw: 0, roll: state.cameraOrbit.degreesToRadians)

         let lastColumn = matrix.columns.3

         */
        // let computed_transform = matrix_identity_float4x4 * combinedRotationTransform.matrix * translationTransform.matrix

        // return rotation.act(Vector(state.cameraDollySide, -200, state.cameraDollyUp))

        return Vector(0, 0, 0)
    }

    var rotation: Quat {
        let cameraOrbit = Quat(angle: state.cameraOrbit.degreesToRadians, axis: Vector(0, 0, 1))
        let cameraTilt = Quat(angle: -state.cameraTilt.degreesToRadians, axis: cameraOrbit.act(Vector(1, 0, 0)))
        return cameraTilt * cameraOrbit

        //  return Quat(pitch: state.cameraTilt.degreesToRadians, jaw: 0, roll: state.cameraOrbit.degreesToRadians)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
