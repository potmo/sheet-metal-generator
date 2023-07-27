import CanvasRender
import simd
import SwiftUI

typealias Vector = simd_double3
typealias Quat = simd_quatd

@main
struct HelloWorld: App {
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

    var body: some Scene {
        WindowGroup {
            VStack {
                HStack {
                    DoubleSlider(label: "Thickness", value: $state.thickness, range: 0.0 ... 5.0)
                    DoubleSlider(label: "Size", value: $state.size, range: 0.0 ... 150.0)
                    DoubleSlider(label: "Height", value: $state.height, range: 0.0 ... 150.0)
                }

                HStack {
                    DoubleSlider(label: "Inner radius", value: $state.bendRadius, range: 0.0 ... 10.0)
                    DoubleSlider(label: "K-Factor", value: $state.kFactor, range: 0.0 ... 1.0)
                }

                HStack {
                    DoubleSlider(label: "X-Angle", value: $state.angleAreoundX, range: -60.0 ... 60.0)
                    DoubleSlider(label: "Y-Angle", value: $state.angleAreoundY, range: -60.0 ... 60.0)
                }

                HStack(spacing: 0) {
                    DoubleSlider(label: "Orbit", value: $state.cameraOrbit, range: 0.0 ... 360.0)
                    DoubleSlider(label: "Tilt", value: $state.cameraTilt, range: -90.0 ... 90.0)
                    DoubleSlider(label: "Side", value: $state.cameraDollySide, range: -100.0 ... 100.0)
                    DoubleSlider(label: "Up", value: $state.cameraDollyUp, range: -100.0 ... 100.0)
                }
            }

            VStack {
                HStack {
                    // CanvasView(state: state, maker: FlatView())
                    CanvasView(state: state, maker: FlatSideView(), renderTransform: AxisAlignedOrthographicTransform(plane: .xy))
                    CanvasView(state: state, maker: FlatSideView(),
                               renderTransform: PerspectiveTransform(camera: StateObjectCamera(state: state)))
                }
                HStack {
                    CanvasView(state: state, maker: FlatSideView(), renderTransform: AxisAlignedOrthographicTransform(plane: .xz))
                    CanvasView(state: state, maker: FlatSideView(), renderTransform: AxisAlignedOrthographicTransform(plane: .yz))
                }
            }
        }
    }
}

private struct StateObjectCamera: PerspectiveCamera {
    private let state: InputState
    init(state: InputState) {
        self.state = state
    }

    var position: Vector {
        return rotation.act(Vector(state.cameraDollySide, -120, state.cameraDollyUp))
    }

    var rotation: Quat {
        let cameraOrbit = Quat(angle: state.cameraOrbit.degreesToRadians, axis: Vector(0, 0, 1))
        let cameraTilt = Quat(angle: -state.cameraTilt.degreesToRadians, axis: cameraOrbit.act(Vector(1, 0, 0)))
        return cameraOrbit
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
