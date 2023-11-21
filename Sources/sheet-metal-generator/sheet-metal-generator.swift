import CanvasRender
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

                print(svgTarget.svg)
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
            DoubleSlider(label: "Size", value: $state.size, range: 0.0 ... 150.0)
        }
        HStack {
            DoubleSlider(label: "Height", value: $state.height, range: 0.0 ... 150.0)
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
                CanvasView(state: state, maker: FromSidesView(),
                           renderTransform: OrthographicTransform(camera: StateObjectCamera(state: state)))
            }else{
                CanvasView(state: state,
                           maker: FromSidesView(),
                           renderTransform: OrthographicTransform(camera: StaticCamera(position: Vector(0, 0, 200),
                                                                                       rotation: Quat(angle: .pi,
                                                                                                      axis: Vector(1, 0, 0)))))
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
                                                                                       rotation: Quat(angle: .pi,
                                                                                                      axis: Vector(1, 0, 0)))))

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
            Group{
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
        self.rotation = Quat(from: Vector(0, 0, -1), to: lookDirection.normalized)
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

        return Vector(0, 0, 200)
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
