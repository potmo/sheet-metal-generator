import AppKit
import CanvasRender
import Cocoa
import Combine
import Foundation
import simd
import SwiftUI

struct FlatView: ShapeMaker {
    typealias StateType = InputState

    private let renderPlane: AxisPlane = .xy

    @CanvasBuilder
    func shapes(from state: InputState) -> [DrawableShape] {
        Decoration(color: .red) {
            Arrow(vector: [3, 0, 0], origo: [0, 0, 0])
        }

        Decoration(color: .green) {
            Arrow(vector: [0, 3, 0], origo: [0, 0, 0])
        }

        let plane = Plane(fitting: state.size,
                          rotatedAroundX: state.angleAroundX,
                          andY: state.angleAroundY,
                          rotatedBackToXyPlane: true)

        Decoration(color: .red, lineStyle: .dashed()) {
            Polygon(vertices: plane.vertices)
        }

        let northBendAngle = +state.angleAroundX
        let eastBendAngle = -state.angleAroundY
        let southBendAngle = -state.angleAroundX
        let westBendAngle = +state.angleAroundY

        let bendAngles = [
            northBendAngle,
            eastBendAngle,
            southBendAngle,
            westBendAngle,
        ]
        .map(\.degreesToRadians)

        let bendAllowances = bendAngles.map { angle in
            return Bend.bendAllowance(angle: .pi / 2 + angle, // add 90 degrees
                                      insideRadius: state.bendRadius,
                                      kFactor: state.kFactor,
                                      materialThickness: state.thickness)
        }

        let projectedPlane = plane
            .north.resizedAlongSides(byDistanceAlongNormal: -bendAllowances[0] / 2)
            .east.resizedAlongSides(byDistanceAlongNormal: -bendAllowances[1] / 2)
            .south.resizedAlongSides(byDistanceAlongNormal: -bendAllowances[2] / 2)
            .west.resizedAlongSides(byDistanceAlongNormal: -bendAllowances[3] / 2)

        let northBendPlane = projectedPlane.north.pushPulledInNormalDirection(by: bendAllowances[0])
        let eastBendPlane = projectedPlane.east.pushPulledInNormalDirection(by: bendAllowances[1])
        let southBendPlane = projectedPlane.south.pushPulledInNormalDirection(by: bendAllowances[2])
        let westBendPlane = projectedPlane.west.pushPulledInNormalDirection(by: bendAllowances[3])

        Decoration(color: .green, lineStyle: .dashed()) {
            Polygon(vertices: projectedPlane.vertices)
        }

        Decoration(color: .blue) {
            Polygon(vertices: northBendPlane.vertices)
            Polygon(vertices: eastBendPlane.vertices)
            Polygon(vertices: southBendPlane.vertices)
            Polygon(vertices: westBendPlane.vertices)
        }

        let northRotation = Quat(angle: bendAngles[0], axis: Vector(0, 0, 1)).act(northBendPlane.north.normal)
        let northSide = northBendPlane.north.pushPulled(by: 50, in: northRotation)

        let eastRotation = Quat(angle: bendAngles[1], axis: Vector(0, 0, 1)).act(eastBendPlane.east.normal)
        let eastSide = eastBendPlane.east.pushPulled(by: 50, in: eastRotation)

        let southRotation = Quat(angle: bendAngles[2], axis: Vector(0, 0, 1)).act(southBendPlane.south.normal)
        let southSide = southBendPlane.south.pushPulled(by: 50, in: southRotation)

        let westRotation = Quat(angle: bendAngles[3], axis: Vector(0, 0, 1)).act(westBendPlane.west.normal)
        let westSide = westBendPlane.west.pushPulled(by: 50, in: westRotation)

        Decoration(color: .indigo) {
            Polygon(vertices: northSide.vertices)
            Polygon(vertices: eastSide.vertices)
            Polygon(vertices: southSide.vertices)
            Polygon(vertices: westSide.vertices)
        }
    }
}
