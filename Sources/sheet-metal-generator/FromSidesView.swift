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

            let straightLeft = Vector(0, 0, 1).cross(sideNormal)

            // FIXME: Remove gap when we dont need it
            let rightSidePadding = state.thickness * 1.3

            let sideInnerTopUnderside0 = topUndersideEdge.vertex0 + relativePivotPoint + bendRotationDown.act(-relativePivotPoint)
            let sidePaddingAlongTopNormal0 = prescaledPlane.edges[index].vertex0 - sideInnerTopUnderside0
            let sidePaddingHorizontal0 = sidePaddingAlongTopNormal0.projected(onto: straightLeft).extended(by: state.thickness)
            let sideOuterTopUnderside0 = sideInnerTopUnderside0 + sidePaddingHorizontal0
            let sideInnerTopOverside0 = sideInnerTopUnderside0 + sideNormal.scaled(by: state.thickness)
            let sideOuterTopOverside0 = sideOuterTopUnderside0 + sideNormal.scaled(by: state.thickness)

            let sideInnerTopUnderside1 = topUndersideEdge.vertex1 + relativePivotPoint + bendRotationDown.act(-relativePivotPoint)
            let sidePaddingAlongTopNormal1 = prescaledPlane.edges[index].vertex1 - sideInnerTopUnderside1

            let sidePaddingHorizontal1 = sidePaddingAlongTopNormal1.projected(onto: straightLeft).extended(by: state.thickness).extended(by: -rightSidePadding)
            let sideOuterTopUnderside1 = sideInnerTopUnderside1 + sidePaddingHorizontal1
            let sideInnerTopOverside1 = sideInnerTopUnderside1 + sideNormal.scaled(by: state.thickness)
            let sideOuterTopOverside1 = sideOuterTopUnderside1 + sideNormal.scaled(by: state.thickness)

            let sideOuterBottomUnderside0 = bottomInsideEdge.vertex0 + straightLeft.scaled(by: state.thickness)
            let sideOuterBottomUnderside1 = bottomInsideEdge.vertex1 - straightLeft.scaled(by: state.thickness - rightSidePadding)

            let sideOuterBottomOverside0 = sideOuterBottomUnderside0 + sideNormal.scaled(by: state.thickness)
            let sideOuterBottomOverside1 = sideOuterBottomUnderside1 + sideNormal.scaled(by: state.thickness)

            Decoration(color: .clear) {
                Decoration(lineStyle: .bendDash) {
                    LineSection(from: topUndersideEdge.vertex0, to: topUndersideEdge.vertex1)
                    LineSection(from: topUndersideEdge.vertex0 + planeNormal.scaled(by: state.thickness), to: topUndersideEdge.vertex1 + planeNormal.scaled(by: state.thickness))
                }

                Orbit(pivot: topUndersideEdge.vertex0 + relativePivotPoint, point: topUndersideEdge.vertex0, rotation: bendRotationDown, spokes: true)
                Orbit(pivot: topUndersideEdge.vertex0 + relativePivotPoint, point: topUndersideEdge.vertex0 + planeNormal.scaled(by: state.thickness), rotation: bendRotationDown, spokes: true)

                Orbit(pivot: topUndersideEdge.vertex1 + relativePivotPoint, point: topUndersideEdge.vertex1, rotation: bendRotationDown, spokes: true)
                Orbit(pivot: topUndersideEdge.vertex1 + relativePivotPoint, point: topUndersideEdge.vertex1 + planeNormal.scaled(by: state.thickness), rotation: bendRotationDown, spokes: true)

                LineSection(from: sideInnerTopUnderside0, to: sideOuterTopUnderside0)
                LineSection(from: sideInnerTopUnderside1, to: sideOuterTopUnderside1)

                Decoration(lineStyle: .dashed()) {
                    LineSection(from: sideInnerTopUnderside0, to: sideInnerTopOverside0)
                    LineSection(from: sideInnerTopUnderside1, to: sideInnerTopOverside1)
                }

                LineSection(from: sideInnerTopOverside0, to: sideOuterTopOverside0)
                LineSection(from: sideInnerTopOverside1, to: sideOuterTopOverside1)

                LineSection(from: sideOuterTopUnderside0, to: sideOuterTopOverside0)
                LineSection(from: sideOuterTopUnderside1, to: sideOuterTopOverside1)

                LineSection(from: sideOuterTopUnderside0, to: sideOuterBottomUnderside0)
                LineSection(from: sideOuterTopUnderside1, to: sideOuterBottomUnderside1)

                LineSection(from: sideOuterTopOverside0, to: sideOuterBottomOverside0)
                LineSection(from: sideOuterTopOverside1, to: sideOuterBottomOverside1)

                LineSection(from: sideOuterBottomUnderside0, to: sideOuterBottomOverside0)
                LineSection(from: sideOuterBottomUnderside1, to: sideOuterBottomOverside1)

                LineSection(from: sideOuterBottomUnderside0, to: sideOuterBottomUnderside1)
                LineSection(from: sideOuterBottomOverside0, to: sideOuterBottomOverside1)
            }

            let insideBendAllowence = state.bendRadius * bendAngle
            let outsideBendAllowence = (state.bendRadius + state.thickness) * bendAngle

            let rotatedUndersideSetback = edge.normal.scaled(by: insideBendAllowence)
            let rotatedOversideSetback = edge.normal.scaled(by: outsideBendAllowence)
            let backrotatedPivotPoint = topUndersideEdge.vertex0 + relativePivotPoint

            let sideInnerTopUnderside0Rotated = sideInnerTopUnderside0.rotated(by: bendRotationDown.inverse, pivot: backrotatedPivotPoint) + rotatedUndersideSetback
            let sideOuterTopUnderside0Rotated = sideOuterTopUnderside0.rotated(by: bendRotationDown.inverse, pivot: backrotatedPivotPoint) + rotatedUndersideSetback

            let sideInnerTopOverside0Rotated = sideInnerTopOverside0.rotated(by: bendRotationDown.inverse, pivot: backrotatedPivotPoint) + rotatedOversideSetback
            let sideOuterTopOverside0Rotated = sideOuterTopOverside0.rotated(by: bendRotationDown.inverse, pivot: backrotatedPivotPoint) + rotatedOversideSetback

            let sideInnerTopUnderside1Rotated = sideInnerTopUnderside1.rotated(by: bendRotationDown.inverse, pivot: backrotatedPivotPoint) + rotatedUndersideSetback
            let sideOuterTopUnderside1Rotated = sideOuterTopUnderside1.rotated(by: bendRotationDown.inverse, pivot: backrotatedPivotPoint) + rotatedUndersideSetback

            let sideInnerTopOverside1Rotated = sideInnerTopOverside1.rotated(by: bendRotationDown.inverse, pivot: backrotatedPivotPoint) + rotatedOversideSetback
            let sideOuterTopOverside1Rotated = sideOuterTopOverside1.rotated(by: bendRotationDown.inverse, pivot: backrotatedPivotPoint) + rotatedOversideSetback

            let sideOuterBottomUnderside0Rotated = sideOuterBottomUnderside0.rotated(by: bendRotationDown.inverse, pivot: backrotatedPivotPoint) + rotatedUndersideSetback
            let sideOuterBottomUnderside1Rotated = sideOuterBottomUnderside1.rotated(by: bendRotationDown.inverse, pivot: backrotatedPivotPoint) + rotatedUndersideSetback

            let sideOuterBottomOverside0Rotated = sideOuterBottomOverside0.rotated(by: bendRotationDown.inverse, pivot: backrotatedPivotPoint) + rotatedOversideSetback
            let sideOuterBottomOverside1Rotated = sideOuterBottomOverside1.rotated(by: bendRotationDown.inverse, pivot: backrotatedPivotPoint) + rotatedOversideSetback

            let lidUndersideCorner0Rotated = topUndersideEdge.vertex0
            let lidUndersideCorner1Rotated = topUndersideEdge.vertex1

            let lidOversideCorner0Rotated = topUndersideEdge.vertex0 + planeNormal.scaled(by: state.thickness)
            let lidOversideCorner1Rotated = topUndersideEdge.vertex1 + planeNormal.scaled(by: state.thickness)

            Decoration(color: .clear) {
                LineSection(from: sideInnerTopUnderside0Rotated, to: sideOuterTopUnderside0Rotated)
                LineSection(from: sideInnerTopUnderside1Rotated, to: sideOuterTopUnderside1Rotated)

                Decoration(lineStyle: .dashed()) {
                    LineSection(from: sideInnerTopUnderside0Rotated, to: sideInnerTopOverside0Rotated)
                    LineSection(from: sideInnerTopUnderside1Rotated, to: sideInnerTopOverside1Rotated)
                }

                LineSection(from: sideInnerTopOverside0Rotated, to: sideOuterTopOverside0Rotated)
                LineSection(from: sideInnerTopOverside1Rotated, to: sideOuterTopOverside1Rotated)

                LineSection(from: sideOuterTopUnderside0Rotated, to: sideOuterTopOverside0Rotated)
                LineSection(from: sideOuterTopUnderside1Rotated, to: sideOuterTopOverside1Rotated)

                LineSection(from: sideOuterTopUnderside0Rotated, to: sideOuterBottomUnderside0Rotated)
                LineSection(from: sideOuterTopUnderside1Rotated, to: sideOuterBottomUnderside1Rotated)

                LineSection(from: sideOuterTopOverside0Rotated, to: sideOuterBottomOverside0Rotated)
                LineSection(from: sideOuterTopOverside1Rotated, to: sideOuterBottomOverside1Rotated)

                LineSection(from: sideOuterBottomUnderside0Rotated, to: sideOuterBottomOverside0Rotated)
                LineSection(from: sideOuterBottomUnderside1Rotated, to: sideOuterBottomOverside1Rotated)

                LineSection(from: sideOuterBottomUnderside0Rotated, to: sideOuterBottomUnderside1Rotated)
                LineSection(from: sideOuterBottomOverside0Rotated, to: sideOuterBottomOverside1Rotated)

                Decoration(lineStyle: .dashed()) {
                    LineSection(from: lidOversideCorner0Rotated, to: lidUndersideCorner0Rotated)
                    LineSection(from: lidOversideCorner1Rotated, to: lidUndersideCorner1Rotated)

                    LineSection(from: lidOversideCorner0Rotated, to: lidOversideCorner1Rotated)
                    LineSection(from: lidUndersideCorner0Rotated, to: lidUndersideCorner1Rotated)
                }

                LineSection(from: lidUndersideCorner0Rotated, to: sideInnerTopUnderside0Rotated)
                LineSection(from: lidUndersideCorner1Rotated, to: sideInnerTopUnderside1Rotated)

                LineSection(from: lidOversideCorner0Rotated, to: sideInnerTopOverside0Rotated)
                LineSection(from: lidOversideCorner1Rotated, to: sideInnerTopOverside1Rotated)
            }
            let projectionRotation = Quat(from: planeNormal, to: Vector(0, 0, 1))
            let sideInnerTopUnderside0Projected = sideInnerTopUnderside0Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
            let sideOuterTopUnderside0Projected = sideOuterTopUnderside0Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
            let sideInnerTopOverside0Projected = sideInnerTopOverside0Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
            let sideOuterTopOverside0Projected = sideOuterTopOverside0Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
            let sideInnerTopUnderside1Projected = sideInnerTopUnderside1Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
            let sideOuterTopUnderside1Projected = sideOuterTopUnderside1Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
            let sideInnerTopOverside1Projected = sideInnerTopOverside1Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
            let sideOuterTopOverside1Projected = sideOuterTopOverside1Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
            let sideOuterBottomUnderside0Projected = sideOuterBottomUnderside0Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
            let sideOuterBottomUnderside1Projected = sideOuterBottomUnderside1Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
            let sideOuterBottomOverside0Projected = sideOuterBottomOverside0Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
            let sideOuterBottomOverside1Projected = sideOuterBottomOverside1Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
            let lidUndersideCorner0Projected = lidUndersideCorner0Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
            let lidUndersideCorner1Projected = lidUndersideCorner1Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
            let lidOversideCorner0Projected = lidOversideCorner0Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
            let lidOversideCorner1Projected = lidOversideCorner1Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))

            Decoration(color: .green) {
                LineSection(from: sideInnerTopUnderside0Projected, to: sideOuterTopUnderside0Projected)
                LineSection(from: sideInnerTopUnderside1Projected, to: sideOuterTopUnderside1Projected)

                //Decoration(lineStyle: .dashed()) {
                 //   LineSection(from: sideInnerTopUnderside0Projected, to: sideInnerTopOverside0Projected)
                //    LineSection(from: sideInnerTopUnderside1Projected, to: sideInnerTopOverside1Projected)
                //}

              //  LineSection(from: sideInnerTopOverside0Projected, to: sideOuterTopOverside0Projected)
               // LineSection(from: sideInnerTopOverside1Projected, to: sideOuterTopOverside1Projected)

               // LineSection(from: sideOuterTopUnderside0Projected, to: sideOuterTopOverside0Projected)
               // LineSection(from: sideOuterTopUnderside1Projected, to: sideOuterTopOverside1Projected)

                LineSection(from: sideOuterTopUnderside0Projected, to: sideOuterBottomUnderside0Projected)
                LineSection(from: sideOuterTopUnderside1Projected, to: sideOuterBottomUnderside1Projected)

               // LineSection(from: sideOuterTopOverside0Projected, to: sideOuterBottomOverside0Projected)
               // LineSection(from: sideOuterTopOverside1Projected, to: sideOuterBottomOverside1Projected)

                //LineSection(from: sideOuterBottomUnderside0Projected, to: sideOuterBottomOverside0Projected)
                //LineSection(from: sideOuterBottomUnderside1Projected, to: sideOuterBottomOverside1Projected)

                LineSection(from: sideOuterBottomUnderside0Projected, to: sideOuterBottomUnderside1Projected)
              //  LineSection(from: sideOuterBottomOverside0Projected, to: sideOuterBottomOverside1Projected)

                Decoration(lineStyle: .dashed()) {
                   // LineSection(from: lidOversideCorner0Projected, to: lidUndersideCorner0Projected)
                  //  LineSection(from: lidOversideCorner1Projected, to: lidUndersideCorner1Projected)

                  //  LineSection(from: lidOversideCorner0Projected, to: lidOversideCorner1Projected)
                    LineSection(from: lidUndersideCorner0Projected, to: lidUndersideCorner1Projected)
                }

                LineSection(from: lidUndersideCorner0Projected, to: sideInnerTopUnderside0Projected)
                LineSection(from: lidUndersideCorner1Projected, to: sideInnerTopUnderside1Projected)

                //LineSection(from: lidOversideCorner0Projected, to: sideInnerTopOverside0Projected)
                //LineSection(from: lidOversideCorner1Projected, to: sideInnerTopOverside1Projected)
            }
        }
    }
}
