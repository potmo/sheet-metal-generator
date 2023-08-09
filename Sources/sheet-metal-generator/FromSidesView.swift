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
            Vector(-state.size / 2, state.size / 2, 0),
            Vector(state.size / 2, state.size / 2, 0),
            Vector(state.size / 2, -state.size / 2, 0),
            Vector(-state.size / 2, -state.size / 2, 0),
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

        let prescaledPlane = Plane(fitting: state.size, // offset in to make space for sheet thickness
                                   normal: planeNormal)

        let midPlane = prescaledPlane.vertices.reduce(Vector(), +).scaled(by: 1 / 4)

        Decoration(color: .purple) {
            Arrow(vector: prescaledPlane.normal.scaled(by: 30), origo: midPlane)
        }

        let height = state.size
        let bottomOutline = outline.map { vertice in vertice + Vector(0, 0, -height) }

        Decoration(color: .gray, lineStyle: .dashed()) {
            Polygon(vertices: prescaledPlane.vertices)

            Polygon(vertices: bottomOutline)

            zip(prescaledPlane.vertices, bottomOutline).map { top, bottom in
                LineSection(from: top, to: bottom)
            }
        }

        Decoration(color: .gray) {
            Circle(center: prescaledPlane.west.middle, radius: 2)
        }

        let sideNormals = [
            Vector(0, 1, 0),
            Vector(1, 0, 0),
            Vector(0, -1, 0),
            Vector(-1, 0, 0),
        ]

        for (index, edge) in prescaledPlane.edges.enumerated() {
            let bendAngle = bendAngles[index]
            let sideNormal = sideNormals[index]

            let outsideSetback = Bend.outsideSetback(angle: bendAngle,
                                                     radius: state.bendRadius,
                                                     thickness: state.thickness)

            // drop is perpendicular to edge
            let drop = edge.middle + sideNormal.cross(edge.direction).scaled(by: outsideSetback)
            let pivotPoint = drop + sideNormal.scaled(by: -(state.bendRadius + state.thickness))

            Decoration(color: .gray, lineStyle: .dashed()) {
                LineSection(from: edge.middle, to: drop)
                LineSection(from: drop + edge.edge.scaled(by: -0.5), to: drop + edge.edge.scaled(by: 0.5))
                LineSection(from: drop, to: pivotPoint)
            }

            Decoration(color: .gray) {
                Circle(center: pivotPoint, radius: 2)
            }

            Decoration(color: .blue) {
                Orbit(pivot: pivotPoint,
                      point: drop,
                      rotation: Quat(angle: bendAngle, axis: edge.direction))
            }

            Decoration(color: .red) {
                Orbit(pivot: pivotPoint,
                      point: (drop - pivotPoint).normalized.scaled(by: state.bendRadius) + pivotPoint,
                      rotation: Quat(angle: bendAngle, axis: edge.direction))
            }
        }
    }
}
