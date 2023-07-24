import AppKit
import CanvasRender
import Cocoa
import Combine
import Foundation
import simd
import SwiftUI

struct FlatSideView: ShapeMaker {
    typealias StateType = InputState

    let renderPlane: AxisPlane

    @CanvasBuilder
    func shapes(from state: InputState) -> [DrawableShape] {
        Decoration(color: .cyan) {
            Circle(center: [0, 0, 0], radius: 3, plane: renderPlane)
        }

        Decoration(color: .red) {
            Arrow(vector: [3, 0, 0], origo: [0, 0, 0], plane: renderPlane)
        }

        Decoration(color: .green) {
            Arrow(vector: [0, 3, 0], origo: [0, 0, 0], plane: renderPlane)
        }

        Decoration(color: .blue) {
            Arrow(vector: [0, 0, 3], origo: [0, 0, 0], plane: renderPlane)
        }

        // draw outline
        Decoration(color: .orange, lineStyle: .dashed()) {
            let outline = [
                Vector(-state.size / 2, -state.size / 2, 0),
                Vector(state.size / 2, -state.size / 2, 0),
                Vector(state.size / 2, state.size / 2, 0),
                Vector(-state.size / 2, state.size / 2, 0),
            ]
            Polygon(vertices: outline, renderPlane: renderPlane)
        }

        let northBendAngle = +state.angleAreoundX
        let eastBendAngle = -state.angleAreoundY
        let southBendAngle = -state.angleAreoundX
        let westBendAngle = +state.angleAreoundY

        let bendAngles = [
            northBendAngle,
            eastBendAngle,
            southBendAngle,
            westBendAngle,
        ]
        .map(\.degreesToRadians)

        let prescaledPlane = Plane(fitting: state.size, // offset in to make space for sheet thickness
                                   rotatedAroundX: state.angleAreoundX,
                                   andY: state.angleAreoundY)

        Decoration(color: .green, lineStyle: .dashed()) {
            Polygon(vertices: prescaledPlane.vertices, renderPlane: renderPlane)
        }

        // since the edges gets distorted because of the compound angle we have to correct them so that
        // the bend ends up being 90° around the bend line
        // this should be the xAngle and yAngle but isnt
        // we are going for a bend that ends up pointing straight down so lets just meshure what that would be
        var computedAngles = [prescaledPlane.north, prescaledPlane.east, prescaledPlane.south, prescaledPlane.west].map { side -> Double in
            // let horizontalVector = side.normal//.with(z: 0).normalized
            return -side.normal.angleBetween(and: Vector(0, 0, -1), around: side.direction)
        }
        // .enumerated().map { i, _ in .pi / 2 + bendAngles[i] } // replace with original angles

        let bendAllowances = computedAngles.map { angle in

            return Bend.bendAllowance(angle: angle,
                                      insideRadius: state.bendRadius,
                                      kFactor: state.kFactor,
                                      materialThickness: state.thickness)
        }

        let outsideSetbacks = computedAngles.map { angle in
            return Bend.outsideSetback(angle: angle, radius: state.bendRadius, thickness: state.thickness)
        }

        let insideSetbacks = computedAngles.map { angle in
            return Bend.insideSetback(angle: angle, radius: state.bendRadius)
        }

        let plane = prescaledPlane
            .north.resizedAlongSides(byDistanceAlongNormal: -insideSetbacks[0])
            .east.resizedAlongSides(byDistanceAlongNormal: -insideSetbacks[1])
            .south.resizedAlongSides(byDistanceAlongNormal: -insideSetbacks[2])
            .west.resizedAlongSides(byDistanceAlongNormal: -insideSetbacks[3])

        Decoration(color: .green) {
            Arrow(vector: plane.north.normal.scaled(by: 10.0), origo: plane.north.vertex0, plane: renderPlane)
        }

        let neutralPlane = plane.offsetted(by: plane.normal * state.thickness * state.kFactor)
        let topPlane = plane.offsetted(by: plane.normal * state.thickness)

        Decoration(color: .blue) {
            Polygon(vertices: plane.vertices, renderPlane: renderPlane)
        }

        Decoration(color: .black, lineStyle: .dashed()) {
            Polygon(vertices: neutralPlane.vertices, renderPlane: renderPlane)
        }

        Decoration(color: .red) {
            Polygon(vertices: topPlane.vertices, renderPlane: renderPlane)
        }

        let northRotationPoint = plane.north.vertex0 + plane.normal * -state.bendRadius
        let northRotationAxis = -plane.north.direction

        let northRotation = Quat(angle: computedAngles[0], axis: northRotationAxis)

        Decoration(color: .red) {
            Orbit(pivot: northRotationPoint,
                  point: plane.north.vertex0,
                  rotation: northRotation,
                  renderPlane: renderPlane)
        }

        Decoration(lineStyle: .dashed()) {
            Orbit(pivot: northRotationPoint,
                  point: plane.north.vertex0 + plane.normal * state.thickness * state.kFactor,
                  rotation: northRotation,
                  renderPlane: renderPlane)
        }

        Decoration(color: .red) {
            Orbit(pivot: northRotationPoint,
                  point: plane.north.vertex0 + plane.normal * state.thickness,
                  rotation: northRotation,
                  renderPlane: renderPlane)
        }

        let northEndPoint = northRotationPoint + northRotation.act(plane.north.vertex0 - northRotationPoint)
        Circle(center: northEndPoint, radius: 2, plane: renderPlane)

        let tangent = northRotation.act(plane.north.normal)

        LineSection(from: northEndPoint, to: northEndPoint + tangent.scaled(by: 30), plane: renderPlane)

        Decoration(color: .cyan, lineStyle: .dashed()) {
            Arrow(from: plane.north.vertex0,
                  to: plane.north.vertex0 + plane.north.normal * insideSetbacks[0],
                  plane: renderPlane)

            Arrow(from: plane.north.vertex0 + plane.north.normal * insideSetbacks[0],
                  to: plane.north.vertex0 + plane.north.normal * insideSetbacks[0] + northRotation.act(plane.north.normal * insideSetbacks[0]),
                  plane: renderPlane)

            Arrow(from: plane.north.vertex0 + plane.normal * state.thickness,
                  to: plane.north.vertex0 + plane.normal * state.thickness + plane.north.normal * outsideSetbacks[0], plane: renderPlane)

            Arrow(from: plane.north.vertex0 + plane.normal * state.thickness + plane.north.normal * outsideSetbacks[0],
                  to: plane.north.vertex0 + plane.normal * state.thickness + plane.north.normal * outsideSetbacks[0] + northRotation.act(plane.north.normal * outsideSetbacks[0]),
                  plane: renderPlane)
        }
    }
}
