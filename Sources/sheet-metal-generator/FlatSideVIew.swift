import AppKit
import CanvasRender
import Cocoa
import Combine
import Foundation
import simd
import SwiftUI

struct FlatSideView: ShapeMaker {
    typealias StateType = InputState

    @CanvasBuilder
    func shapes(from state: StateType) -> [DrawableShape] {
        let state = state.frozen
        
        Decoration(color: .cyan) {
            Circle(center: [0, 0, 0], radius: 3)
        }

        Decoration(color: .red) {
            Arrow(vector: [3, 0, 0], origo: [0, 0, 0])
        }

        Decoration(color: .green) {
            Arrow(vector: [0, 3, 0], origo: [0, 0, 0])
        }

        Decoration(color: .blue) {
            Arrow(vector: [0, 0, 3], origo: [0, 0, 0])
        }

        // draw outline
        Decoration(color: .orange, lineStyle: .dashed()) {
            let outline = [
                Vector(-state.size / 2, -state.size / 2, 0),
                Vector(state.size / 2, -state.size / 2, 0),
                Vector(state.size / 2, state.size / 2, 0),
                Vector(-state.size / 2, state.size / 2, 0),
            ]
            Polygon(vertices: outline)
        }

        let northBendAngle = +state.angleAroundX
        let eastBendAngle = -state.angleAroundY
        let southBendAngle = -state.angleAroundX
        let westBendAngle = +state.angleAroundY

        let bendAngles = [
            northBendAngle + 90,
            eastBendAngle + 90,
            southBendAngle + 90,
            westBendAngle + 90,
        ]
        .map(\.degreesToRadians)

        let localYAxis = Quat(angle: state.angleAroundX.degreesToRadians, axis: Vector(1, 0, 0)).act(Vector(0, 1, 0))
        let localXAxis = Quat(angle: state.angleAroundY.degreesToRadians, axis: Vector(0, 1, 0)).act(Vector(1, 0, 0))
        let planeNormal = localXAxis.cross(localYAxis).normalized

        let prescaledPlane = Plane(fitting: state.size, // offset in to make space for sheet thickness
                                   normal: planeNormal)

        Decoration(color: .green, lineStyle: .dashed()) {
            Polygon(vertices: prescaledPlane.vertices)
        }

        let midPlane = prescaledPlane.vertices.reduce(Vector(), +).scaled(by: 1 / 4)

        Decoration(color: .purple) {
            Arrow(vector: prescaledPlane.normal.scaled(by: 30), origo: midPlane)
        }

        Decoration(color: .mint) {
            Arrow(vector: planeNormal.scaled(by: 30), origo: midPlane)
        }

        // since the edges gets distorted because of the compound angle we have to correct them so that
        // the bend ends up being 90° around the bend line
        // this should be the xAngle and yAngle but isnt
        // we are going for a bend that ends up pointing straight down so lets just meshure what that would be
        /*
         var computedAngles = [prescaledPlane.north, prescaledPlane.east, prescaledPlane.south, prescaledPlane.west].map { side -> Double in
             // let horizontalVector = side.normal//.with(z: 0).normalized
             return -side.normal.angleBetween(and: Vector(0, 0, -1), around: side.direction)
         }
          */
        // .enumerated().map { i, _ in .pi / 2 + bendAngles[i] } // replace with original angles

        let bendAllowances = bendAngles.map { angle in

            return Bend.bendAllowance(angle: angle,
                                      insideRadius: state.bendRadius,
                                      kFactor: state.kFactor,
                                      materialThickness: state.thickness)
        }

        let outsideSetbacks = bendAngles.map { angle in
            return Bend.outsideSetback(angle: angle, radius: state.bendRadius, thickness: state.thickness)
        }

        let insideSetbacks = bendAngles.map { angle in
            return Bend.insideSetback(angle: angle, radius: state.bendRadius)
        }

        let plane = prescaledPlane
            .north.resizedAlongSides(byDistanceAlongNormal: -outsideSetbacks[0])
            .east.resizedAlongSides(byDistanceAlongNormal: -outsideSetbacks[1])
            .south.resizedAlongSides(byDistanceAlongNormal: -outsideSetbacks[2])
            .west.resizedAlongSides(byDistanceAlongNormal: -outsideSetbacks[3])

        Decoration(color: .green) {
            Arrow(vector: plane.north.normal.scaled(by: 10.0), origo: plane.north.vertex0)
        }

        let neutralPlane = plane.offsetted(by: plane.normal * state.thickness * state.kFactor)
        let topPlane = plane.offsetted(by: plane.normal * state.thickness)

        Decoration(color: .blue) {
            Polygon(vertices: plane.vertices)
        }

        Decoration(color: .black, lineStyle: .dashed()) {
            Polygon(vertices: neutralPlane.vertices)
        }

        Decoration(color: .red) {
            Polygon(vertices: topPlane.vertices)
        }

        let northRotationPoint = plane.north.vertex0 + plane.normal * -state.bendRadius
        let northRotationAxis = -plane.north.direction

        let northRotation = Quat(angle: bendAngles[0], axis: northRotationAxis)

        Decoration(color: .red) {
            OrbitCounterClockwise(pivot: northRotationPoint,
                                  point: plane.north.vertex0,
                                  rotation: northRotation)
        }

        Decoration(lineStyle: .dashed()) {
            OrbitCounterClockwise(pivot: northRotationPoint,
                                  point: plane.north.vertex0 + plane.normal * state.thickness * state.kFactor,
                                  rotation: northRotation)
        }

        Decoration(color: .red) {
            OrbitCounterClockwise(pivot: northRotationPoint,
                                  point: plane.north.vertex0 + plane.normal * state.thickness,
                                  rotation: northRotation)
        }

        let northEndPoint = northRotationPoint + northRotation.act(plane.north.vertex0 - northRotationPoint)
        Circle(center: northEndPoint, radius: 20)

        let tangent = northRotation.act(plane.north.normal)

        LineSection(from: northEndPoint, to: northEndPoint + tangent.scaled(by: 30))

        Decoration(color: .cyan, lineStyle: .dashed()) {
            Arrow(from: plane.north.vertex0,
                  to: plane.north.vertex0 + plane.north.normal * insideSetbacks[0])

            Arrow(from: plane.north.vertex0 + plane.north.normal * insideSetbacks[0],
                  to: plane.north.vertex0 + plane.north.normal * insideSetbacks[0] + northRotation.act(plane.north.normal * insideSetbacks[0]))

            Arrow(from: plane.north.vertex0 + plane.normal * state.thickness,
                  to: plane.north.vertex0 + plane.normal * state.thickness + plane.north.normal * outsideSetbacks[0])

            Arrow(from: plane.north.vertex0 + plane.normal * state.thickness + plane.north.normal * outsideSetbacks[0],
                  to: plane.north.vertex0 + plane.normal * state.thickness + plane.north.normal * outsideSetbacks[0] + northRotation.act(plane.north.normal * outsideSetbacks[0]))
        }
    }
}
