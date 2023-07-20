import Foundation

class InputState: ObservableObject {
    
    @PublishedAppStorage("size") var size = 50.0
    @PublishedAppStorage("height") var height = 50.0
    @PublishedAppStorage("thickness") var thickness = 1.0
    @PublishedAppStorage("bend_radius") var bendRadius = 1.0
    @PublishedAppStorage("k_factor") var kFactor = 0.44
    @PublishedAppStorage("angele_around_x") var angleAreoundX = 0.0
    @PublishedAppStorage("angele_around_y") var angleAreoundY = 0.0

    init() {
    }
}
