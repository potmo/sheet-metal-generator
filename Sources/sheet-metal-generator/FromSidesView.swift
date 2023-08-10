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
        let outline = [
            Vector(-state.size / 2 + state.thickness, +state.size / 2 - state.thickness, 0),
            Vector(+state.size / 2 - state.thickness, +state.size / 2 - state.thickness, 0),
            Vector(+state.size / 2 - state.thickness, -state.size / 2 + state.thickness, 0),
            Vector(-state.size / 2 + state.thickness, -state.size / 2 + state.thickness, 0),
        ]
        Decoration(color: .orange, lineStyle: .dashed()) {
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

        let prescaledPlane = Plane(fitting: state.size - state.thickness * 2, // offset in to make space for sheet thickness
                                   normal: planeNormal)

        let midPlane = prescaledPlane.vertices.reduce(Vector(), +).scaled(by: 1 / 4)

        Decoration(color: .purple) {
            Arrow(vector: prescaledPlane.normal.scaled(by: 10), origo: midPlane)
        }

        Decoration(color: .mint) {
            Arrow(from: Vector(), to: localXAxis.scaled(by: 20))
            Arrow(from: Vector(), to: localYAxis.scaled(by: 20))
        }

        let height = state.size
        let bottomOutline = outline.map { vertice in vertice + Vector(0, 0, -height) }
        let bottomOutlinePlane = Plane(vertices: bottomOutline)

        Decoration(color: .gray, lineStyle: .regularDash) {
            Polygon(vertices: prescaledPlane.vertices)

            Polygon(vertices: bottomOutlinePlane.vertices)

            zip(prescaledPlane.vertices, bottomOutlinePlane.vertices).map { top, bottom in
                LineSection(from: top, to: bottom)
            }
        }

        Decoration(color: .gray) {
            for edge in prescaledPlane.edges {
                Circle(center: edge.middle, radius: 2)
            }

            Decoration(lineStyle: .dashed(phase: 2, lengths: [5, 1])) {
                LineSection(from: prescaledPlane.north.middle, to: prescaledPlane.south.middle)
                LineSection(from: prescaledPlane.west.middle, to: prescaledPlane.east.middle)
            }
        }

        let scalingAmounts = bendAngles.map { bendAngle in
            return Bend.insideSetback(angle: bendAngle,
                                      radius: state.bendRadius)
        }

        let sideNormals = [
            Vector(0, 1, 0),
            Vector(1, 0, 0),
            Vector(0, -1, 0),
            Vector(-1, 0, 0),
        ]

        let scaledBottomPlane = prescaledPlane
            .north.resizedAlongSides(by: -scalingAmounts[0])
            .east.resizedAlongSides(by: -scalingAmounts[1])
            .south.resizedAlongSides(by: -scalingAmounts[2])
            .west.resizedAlongSides(by: -scalingAmounts[3])

        Decoration(color: .blue, lineStyle: .bendDash) {
            Polygon(vertices: scaledBottomPlane.vertices)
        }

        for (index, edge) in prescaledPlane.edges.enumerated() {
            let bendAngle = bendAngles[index]
            let sideNormal = sideNormals[index]
            let insideSetback = scalingAmounts[index]
            let scaledEdge = scaledBottomPlane.edges[index]
            let bottomEdge = bottomOutlinePlane.edges[index]

            // drop is perpendicular to edge
            let drop = edge.middle + Vector(0, 0, -insideSetback)
            let lever = sideNormal.scaled(by: -(state.bendRadius))
            let pivotPoint = drop + lever
            let bendRotation = Quat(angle: bendAngle, axis: sideNormal.cross(Vector(0, 0, 1)))
            let bendPoint = pivotPoint + bendRotation.act(lever.scaled(by: -1))

            let dropRelativeToBendPoint = drop - bendPoint
            let pivotPointRelativeToBendPoint = pivotPoint - bendPoint

            let firstScaledCorner = scaledEdge.middle + scaledEdge.edge.scaled(by: -0.5)
            let secondScaledCorner = scaledEdge.middle + scaledEdge.edge.scaled(by: 0.5)

            let firstFullCorner = drop + edge.edge.scaled(by: -0.5)
            let secondFullCorner = drop + edge.edge.scaled(by: 0.5)

            Decoration(color: .gray, lineStyle: .regularDash) {
                LineSection(from: edge.middle, to: drop)
                LineSection(from: drop + edge.edge.scaled(by: -0.1), to: drop + edge.edge.scaled(by: 0.1))
                LineSection(from: drop, to: pivotPoint)
            }

            Decoration(color: .gray) {
                Circle(center: pivotPoint, radius: 2)
                Circle(center: bendPoint, radius: 2)
            }

            Decoration(color: .blue) {
                Orbit(pivot: firstScaledCorner + pivotPointRelativeToBendPoint,
                      point: firstScaledCorner + dropRelativeToBendPoint,
                      rotation: bendRotation)

                Orbit(pivot: secondScaledCorner + pivotPointRelativeToBendPoint,
                      point: secondScaledCorner + dropRelativeToBendPoint,
                      rotation: bendRotation)
            }

            Decoration(color: .blue, lineStyle: .bendDash) {
                LineSection(from: firstScaledCorner + dropRelativeToBendPoint, to: secondScaledCorner + dropRelativeToBendPoint)
            }

            Decoration(color: .blue) {
                LineSection(from: firstFullCorner, to: firstScaledCorner + dropRelativeToBendPoint)
                LineSection(from: secondScaledCorner + dropRelativeToBendPoint, to: secondFullCorner)

                LineSection(from: firstFullCorner, to: bottomEdge.vertex0)
                LineSection(from: secondFullCorner, to: bottomEdge.vertex1)
                LineSection(from: bottomEdge.vertex0, to: bottomEdge.vertex1)
            }
        }
    }
}
