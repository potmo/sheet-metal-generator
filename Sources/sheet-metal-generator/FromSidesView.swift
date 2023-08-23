import AppKit
import CanvasRender
import Cocoa
import Combine
import Foundation
import simd
import SwiftUI

struct FromSidesView: ShapeMaker {
    typealias StateType = InputState

    @CanvasBuilder
    func shapes(from state: InputState) -> [DrawableShape] {
        // LineSection(from: Vector(), to: Vector(100, 0, 0))

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

        let localYAxis = Quat(angle: state.angleAroundX.degreesToRadians, axis: Vector(1, 0, 0)).act(Vector(0, 1, 0))
        let localXAxis = Quat(angle: state.angleAroundY.degreesToRadians, axis: Vector(0, 1, 0)).act(Vector(1, 0, 0))
        let planeNormal = localXAxis.cross(localYAxis).normalized

        // draw outline
        let innerSize = state.size - state.thickness * 2
        let innerOutline = [
            Vector(-innerSize / 2, +innerSize / 2, 0),
            Vector(+innerSize / 2, +innerSize / 2, 0),
            Vector(+innerSize / 2, -innerSize / 2, 0),
            Vector(-innerSize / 2, -innerSize / 2, 0),
        ]

        let outsideOutline = [
            Vector(-state.size / 2, +state.size / 2, 0),
            Vector(+state.size / 2, +state.size / 2, 0),
            Vector(+state.size / 2, -state.size / 2, 0),
            Vector(-state.size / 2, -state.size / 2, 0),
        ]

        let sideNormals = [
            Vector(0, 1, 0),
            Vector(1, 0, 0),
            Vector(0, -1, 0),
            Vector(-1, 0, 0),
        ]

        let outsideBottomOutline = outsideOutline.map {
            $0.with(z: -state.height)
        }

        Decoration(color: .orange, lineStyle: .dashed()) {
            Polygon(vertices: innerOutline)
            Polygon(vertices: outsideOutline)

            zip(outsideOutline, outsideBottomOutline).map { top, bottom in
                LineSection(from: top, to: bottom)
            }

            Polygon(vertices: outsideBottomOutline)
        }

        let bendRotations = sideNormals.map { sideNormal in
            return Quat(from: planeNormal, to: sideNormal)
        }

        /*
         let bendAngles = [
             northBendAngle + 90,
             eastBendAngle + 90,
             southBendAngle + 90,
             westBendAngle + 90,
         ]
         .map(\.degreesToRadians)
         */

        let bendAngles = bendRotations.map { bendRotation in
            bendRotation.angle
        }

        let prescaledPlane = Plane(fitting: state.size - state.thickness * 2, // offset in to make space for sheet thickness
                                   normal: planeNormal)

        let midPlane = prescaledPlane.vertices.reduce(Vector(), +).scaled(by: 1 / 4)

        Decoration(color: .purple) {
            Arrow(vector: prescaledPlane.normal.scaled(by: 10), origo: midPlane)
        }
        /*
         Decoration(color: .mint) {
             Arrow(from: Vector(), to: localXAxis.scaled(by: 20))
             Arrow(from: Vector(), to: localYAxis.scaled(by: 20))
         }
         */

        let bottomOutline = innerOutline.map { vertice in vertice.with(z: -state.height) }
        let bottomOutlinePlane = Plane(vertices: bottomOutline)

        let insideSetbacks = bendAngles.map { bendAngle in
            return Bend.insideSetback(angle: bendAngle,
                                      radius: state.bendRadius)
        }

        let outsideSetbacks = bendAngles.map { bendAngle in
            return Bend.outsideSetback(angle: bendAngle,
                                       radius: state.bendRadius,
                                       thickness: state.thickness)
        }

        let bendAllowances = bendAngles.map { bendAngle in
            return Bend.bendAllowance(angle: bendAngle,
                                      insideRadius: state.bendRadius,
                                      kFactor: state.kFactor,
                                      materialThickness: state.thickness)
        }

        let otherSideDirections = [
            prescaledPlane.east.direction,
            prescaledPlane.south.direction,
            prescaledPlane.west.direction,
            prescaledPlane.north.direction,
        ]

        let topUndersidePlane = prescaledPlane
            .north.offsetted(by: planeNormal.cross(bendRotations[0].axis).scaled(by: insideSetbacks[0]).projected(ontoPlaneWithNormal: sideNormals[1]))
            .east.offsetted(by: planeNormal.cross(bendRotations[1].axis).scaled(by: insideSetbacks[1]).projected(ontoPlaneWithNormal: sideNormals[2]))
            .south.offsetted(by: planeNormal.cross(bendRotations[2].axis).scaled(by: insideSetbacks[2]).projected(ontoPlaneWithNormal: sideNormals[3]))
            .west.offsetted(by: planeNormal.cross(bendRotations[3].axis).scaled(by: insideSetbacks[3]).projected(ontoPlaneWithNormal: sideNormals[0]))

        for (index, edge) in prescaledPlane.edges.enumerated() {
            let bendAngle = bendAngles[index]
            let sideNormal = sideNormals[index]
            let insideSetback = insideSetbacks[index]
            let outsideSetback = outsideSetbacks[index]
            let topUndersideEdge = topUndersidePlane.edges[index]
            let bottomInsideEdge = bottomOutlinePlane.edges[index]
            let bendAllowance = bendAllowances[index]

            let relativePivotPoint = prescaledPlane.normal.scaled(by: -state.bendRadius)

            let bendRotationDown = bendRotations[index]

            Decoration(color: .red) {
                Decoration(lineStyle: .bendDash) {
                    LineSection(from: topUndersideEdge.vertex0, to: topUndersideEdge.vertex1)
                    LineSection(from: topUndersideEdge.vertex0 + planeNormal.scaled(by: state.thickness), to: topUndersideEdge.vertex1 + planeNormal.scaled(by: state.thickness))
                }

                LineSection(from: bottomInsideEdge.vertex0, to: bottomInsideEdge.vertex1)

                Orbit(pivot: topUndersideEdge.vertex0 + relativePivotPoint, point: topUndersideEdge.vertex0, rotation: bendRotationDown, spokes: true)
                Orbit(pivot: topUndersideEdge.vertex0 + relativePivotPoint, point: topUndersideEdge.vertex0 + prescaledPlane.normal.scaled(by: state.thickness), rotation: bendRotationDown, spokes: true)

                Orbit(pivot: topUndersideEdge.vertex1 + relativePivotPoint, point: topUndersideEdge.vertex1, rotation: bendRotationDown, spokes: true)
                Orbit(pivot: topUndersideEdge.vertex1 + relativePivotPoint, point: topUndersideEdge.vertex1 + prescaledPlane.normal.scaled(by: state.thickness), rotation: bendRotationDown, spokes: true)

                let sideTop0 = topUndersideEdge.vertex0 + relativePivotPoint + bendRotationDown.act(-relativePivotPoint)
                let sideTop0out = topUndersideEdge.vertex0 + relativePivotPoint + bendRotationDown.act(-relativePivotPoint) + sideNormal.scaled(by: state.thickness)

                Decoration(color: .blue) {
                    Arrow(from: topUndersideEdge.vertex0, to: sideTop0)
                    let sideA = prescaledPlane.edges[index].vertex0 - sideTop0
                    let straightLeft = Vector(0,0,1).cross(sideNormal)

                    let aOnLeft = sideA.projected(onto: straightLeft).extended(by: state.thickness)
                    Arrow(vector: sideA, origo: sideTop0)
                    Arrow(vector: straightLeft.scaled(by: 5), origo: sideTop0)

                    Decoration(color: .green) {
                        Arrow(vector: aOnLeft, origo: sideTop0)
                        Arrow(vector: aOnLeft, origo: sideTop0out)
                    }

                }
            }
        }
    }
}
