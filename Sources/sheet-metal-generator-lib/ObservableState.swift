import CanvasRender
import Combine
import Foundation

public class InputState: ObservableObject {
    @PublishedAppStorage("size") public var size = 50.0
    @PublishedAppStorage("height") public var height = 50.0
    @PublishedAppStorage("thickness") public var thickness = 1.0
    @PublishedAppStorage("bend_radius") public var bendRadius = 1.0
    @PublishedAppStorage("gap_scalar") public var gapScalar = 1.5
    @PublishedAppStorage("hole_clearence") public var holeClearence = 0.2
    @PublishedAppStorage("fastener_thickness") public var fastenerThickness = 0.25
    @PublishedAppStorage("fastener_width") public var fastenerWidth = 4.6

    @PublishedAppStorage("k_factor") public var kFactor = 0.44
    @PublishedAppStorage("angle_around_x") public var angleAroundX = 0.0
    @PublishedAppStorage("angle_around_y") public var angleAroundY = 0.0

    @PublishedAppStorage("angleSlerp") public var angleSlerp = 0.0

    @PublishedAppStorage("cameraOrbit") public var cameraOrbit = 0.0
    @PublishedAppStorage("cameraTilt") public var cameraTilt = 0.0
    @PublishedAppStorage("cameraDollySide") public var cameraDollySide = 0.0
    @PublishedAppStorage("cameraDollyup") public var cameraDollyUp = 0.0

    @PublishedAppStorage("show_horizontal_flat_view") public var showHorizontalFlatView = true
    @PublishedAppStorage("show_top_aligned_flat_view") public var showTopAlignedFlatView = true
    @PublishedAppStorage("show_folded_view") public var showFolded = true

    @PublishedAppStorage("show_3d_view") public var show3dView = true

    @PublishedAppStorage("fullscreen_top") public var fullScreenTop = true

    public var staticNormal: Vector? = nil

    public var firstLabel = "0.1234567890"
    public var secondLabel = "0987654321.0"

    public init() {
    }

    public var frozen: Frozen {
        return Frozen(size: size,
                      height: height,
                      thickness: thickness,
                      fastenerThickness: fastenerThickness,
                      fastenerWidth: fastenerWidth,
                      holeClearence: holeClearence,
                      bendRadius: bendRadius,
                      gapScalar: gapScalar,
                      kFactor: kFactor,
                      angleAroundX: angleAroundX,
                      angleAroundY: angleAroundY,
                      angleSlerp: angleSlerp,
                      cameraOrbit: cameraOrbit,
                      cameraTilt: cameraTilt,
                      cameraDollySide: cameraDollySide,
                      cameraDollyUp: cameraDollyUp,
                      showHorizontalFlatView: showHorizontalFlatView,
                      showTopAlignedFlatView: showTopAlignedFlatView,
                      showFolded: showFolded,
                      show3dView: show3dView,
                      fullScreenTop: fullScreenTop,
                      staticNormal: staticNormal,
                      firstLabel: firstLabel,
                      secondLabel: secondLabel)
    }

    public struct Frozen {
        let size: Double
        let height: Double
        let thickness: Double
        let fastenerThickness: Double
        let fastenerWidth: Double
        let holeClearence: Double
        let bendRadius: Double
        let gapScalar: Double
        let kFactor: Double
        let angleSlerp: Double
        let cameraOrbit: Double
        let cameraTilt: Double
        let cameraDollySide: Double
        let cameraDollyUp: Double
        let showHorizontalFlatView: Bool
        let showTopAlignedFlatView: Bool
        let showFolded: Bool
        let show3dView: Bool
        let fullScreenTop: Bool

        let topFaceNormal: Vector

        let firstLabel: String
        let secondLabel: String

        init(size: Double,
             height: Double,
             thickness: Double,
             fastenerThickness: Double,
             fastenerWidth: Double,
             holeClearence: Double,
             bendRadius: Double,
             gapScalar: Double,
             kFactor: Double,
             angleAroundX: Double,
             angleAroundY: Double,
             angleSlerp: Double,
             cameraOrbit: Double,
             cameraTilt: Double,
             cameraDollySide: Double,
             cameraDollyUp: Double,
             showHorizontalFlatView: Bool,
             showTopAlignedFlatView: Bool,
             showFolded: Bool,
             show3dView: Bool,
             fullScreenTop: Bool,
             staticNormal: Vector?,
             firstLabel: String,
             secondLabel: String) {
            self.size = size
            self.height = height
            self.thickness = thickness
            self.fastenerThickness = fastenerThickness
            self.fastenerWidth = fastenerWidth
            self.holeClearence = holeClearence
            self.bendRadius = bendRadius
            self.gapScalar = gapScalar
            self.kFactor = kFactor
            self.angleSlerp = angleSlerp
            self.cameraOrbit = cameraOrbit
            self.cameraTilt = cameraTilt
            self.cameraDollySide = cameraDollySide
            self.cameraDollyUp = cameraDollyUp
            self.showHorizontalFlatView = showHorizontalFlatView
            self.showTopAlignedFlatView = showTopAlignedFlatView
            self.showFolded = showFolded
            self.show3dView = show3dView
            self.fullScreenTop = fullScreenTop
            self.firstLabel = firstLabel
            self.secondLabel = secondLabel

            if let staticNormal {
                self.topFaceNormal = staticNormal
            } else {
                let xAxisRotation = Quat(angle: angleAroundX.degreesToRadians, axis: Vector(1, 0, 0))
                let yAxisRotation = Quat(angle: angleAroundY.degreesToRadians, axis: Vector(0, 1, 0))
                let localYAxis = xAxisRotation.act(Vector(0, 1, 0))
                let localXAxis = yAxisRotation.act(Vector(1, 0, 0))
                self.topFaceNormal = localXAxis.cross(localYAxis).normalized
            }
        }
    }
}
