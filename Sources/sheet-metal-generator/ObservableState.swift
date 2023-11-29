import CanvasRender
import Combine
import Foundation

class InputState: ObservableObject {
    @PublishedAppStorage("size") var size = 50.0
    @PublishedAppStorage("height") var height = 50.0
    @PublishedAppStorage("thickness") var thickness = 1.0
    @PublishedAppStorage("bend_radius") var bendRadius = 1.0
    @PublishedAppStorage("gap_scalar") var gapScalar = 1.5

    @PublishedAppStorage("k_factor") var kFactor = 0.44
    @PublishedAppStorage("angle_around_x") var angleAroundX = 0.0
    @PublishedAppStorage("angle_around_y") var angleAroundY = 0.0

    @PublishedAppStorage("angleSlerp") var angleSlerp = 0.0

    @PublishedAppStorage("cameraOrbit") var cameraOrbit = 0.0
    @PublishedAppStorage("cameraTilt") var cameraTilt = 0.0
    @PublishedAppStorage("cameraDollySide") var cameraDollySide = 0.0
    @PublishedAppStorage("cameraDollyup") var cameraDollyUp = 0.0

    @PublishedAppStorage("show_horizontal_flat_view") var showHorizontalFlatView = true
    @PublishedAppStorage("show_top_aligned_flat_view") var showTopAlignedFlatView = true
    @PublishedAppStorage("show_folded_view") var showFolded = true

    @PublishedAppStorage("show_3d_view") var show3dView = true

    @PublishedAppStorage("fullscreen_top") var fullScreenTop = true

    init() {
    }

    var frozen: Frozen {
        return Frozen(size: size,
                      height: height,
                      thickness: thickness,
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
                      fullScreenTop: fullScreenTop)
    }

    struct Frozen {
        let size: Double
        let height: Double
        let thickness: Double
        let bendRadius: Double
        let gapScalar: Double
        let kFactor: Double
        let angleAroundX: Double
        let angleAroundY: Double
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
    }
}
