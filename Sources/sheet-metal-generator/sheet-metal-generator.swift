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
            }

            HStack {
                // CanvasView(state: state, maker: FlatView())
                CanvasView(state: state, maker: FlatSideView(renderPlane: .xy))
                CanvasView(state: state, maker: FlatSideView(renderPlane: .xz))
                CanvasView(state: state, maker: FlatSideView(renderPlane: .yz))
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
