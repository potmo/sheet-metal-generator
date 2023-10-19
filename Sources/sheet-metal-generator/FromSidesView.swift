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

        let xAxisRotation = Quat(angle: state.angleAroundX.degreesToRadians, axis: Vector(1, 0, 0))
        let yAxisRotation = Quat(angle: state.angleAroundY.degreesToRadians, axis: Vector(0, 1, 0))
        let localYAxis = xAxisRotation.act(Vector(0, 1, 0))
        let localXAxis = yAxisRotation.act(Vector(1, 0, 0))
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

        Decoration(color: .orange, lineStyle: .regularDash, hidden: true) {
            Polygon(vertices: innerOutline)
            Polygon(vertices: outsideOutline)

            zip(outsideOutline, outsideBottomOutline).map { top, bottom in
                LineSection(from: top, to: bottom)
            }

            Polygon(vertices: outsideBottomOutline)
        }

        let prescaledPlane = Plane(fitting: state.size - state.thickness * 2, // offset in to make space for sheet thickness
                                   normal: planeNormal)

        let bendRotations = sideNormals.enumerated().map { _, sideNormal -> Quat in

            // do the calculations myself since that seems to be slightly more accurate
            let u = planeNormal.normalized
            let v = sideNormal.normalized
            let computed = Quat(real: 1.0 + u.dot(v), imag: u.cross(v)).normalized

            return computed
            // return Quat(angle: computed.angle, axis: axis)

            // this adds a fractional amount of direction in the axis it shoudn't
            // return Quat(from: planeNormal, to: sideNormal).normalized
        }

        let bendAngles = bendRotations.map { bendRotation in
            bendRotation.angle
        }

        let northBendAngle = +state.angleAroundX
        let eastBendAngle = -state.angleAroundY
        let southBendAngle = -state.angleAroundX
        let westBendAngle = +state.angleAroundY

        let oldBendAngles = [
            northBendAngle + 90,
            eastBendAngle + 90,
            southBendAngle + 90,
            westBendAngle + 90,
        ]
        .map(\.degreesToRadians)

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

        let setbackInTopPlane = insideSetbacks.indices.map { index -> Vector in
            let insideSetback = insideSetbacks[index]
            let edgeNormal = planeNormal.cross(bendRotations[index].axis)
            let sideDirection = prescaledPlane.edges[(index + 1) % 4].direction
            let scalar = 1.0 / sideDirection.scalarProjection(onto: edgeNormal)
            return sideDirection.scaled(by: scalar).scaled(by: insideSetback)
        }

        let topUndersidePlane = prescaledPlane
            .north.offsetted(by: setbackInTopPlane[0])
            .east.offsetted(by: setbackInTopPlane[1])
            .south.offsetted(by: setbackInTopPlane[2])
            .west.offsetted(by: setbackInTopPlane[3])

        /*
          Decoration(color: .green) {
         let yAxis = planeNormal.projected(ontoPlaneWithNormal: Vector(1, 0, 0))
         let xAxis = planeNormal.projected(ontoPlaneWithNormal: Vector(0, 1, 0))
              Arrow(vector: xAxis.scaled(by: 20), origo: Vector())

              Arrow(vector: yAxis.scaled(by: 20), origo: Vector())

              let yRot = Quat(from: planeNormal, to: xAxis)
              let xRot = Quat(from: planeNormal, to: yAxis)
              TextString(center: xAxis.scaled(by: 20), text: "x: \(xRot.angle.radiansToDegrees.toFixed(8))°", size: 12)
              TextString(center: yAxis.scaled(by: 20), text: "y: \(yRot.angle.radiansToDegrees.toFixed(8))°", size: 12)
          }
         */

        for (index, edge) in prescaledPlane.edges.enumerated() {
            let bendAngle = bendAngles[index]
            let oldBendAngle = oldBendAngles[index]
            let sideNormal = sideNormals[index]
            let insideSetback = insideSetbacks[index]
            let outsideSetback = outsideSetbacks[index]
            let topUndersideEdge = topUndersidePlane.edges[index]
            let bottomInsideEdge = bottomOutlinePlane.edges[index]
            let bendAllowance = bendAllowances[index]

            let relativePivotPoint = planeNormal.scaled(by: -state.bendRadius)

            let oldBendRotationDown = Quat(angle: oldBendAngle, axis: -topUndersideEdge.direction)
            let bendRotationDown = bendRotations[index]
            let edgeNormal = bendRotationDown.axis.cross(planeNormal)

            let straightLeft = Vector(0, 0, 1).cross(sideNormal)

            let rightSidePadding = state.thickness * state.gapScalar

            let sideInnerTopUnderside0 = topUndersideEdge.vertex0 + relativePivotPoint + sideNormal.scaled(by: state.bendRadius) // bendRotationDown.act(-relativePivotPoint)
            let sidePaddingAlongTopNormal0 = prescaledPlane.edges[index].vertex0 - sideInnerTopUnderside0
            let sidePaddingHorizontal0 = sidePaddingAlongTopNormal0.projected(onto: straightLeft).extended(by: state.thickness)
            let sideOuterTopUnderside0 = sideInnerTopUnderside0 + sidePaddingHorizontal0

            let sideInnerTopOverside0 = sideInnerTopUnderside0 + sideNormal.scaled(by: state.thickness)
            let sideOuterTopOverside0 = sideOuterTopUnderside0 + sideNormal.scaled(by: state.thickness)

            let sideInnerTopNeutral0 = sideInnerTopUnderside0 + sideNormal.scaled(by: state.thickness * state.kFactor)
            let sideOuterTopNeutral0 = sideOuterTopUnderside0 + sideNormal.scaled(by: state.thickness * state.kFactor)

            let sideInnerTopUnderside1 = topUndersideEdge.vertex1 + relativePivotPoint + sideNormal.scaled(by: state.bendRadius) // bendRotationDown.act(-relativePivotPoint)
            let sidePaddingAlongTopNormal1 = prescaledPlane.edges[index].vertex1 - sideInnerTopUnderside1

            let sidePaddingHorizontal1 = sidePaddingAlongTopNormal1.projected(onto: straightLeft).extended(by: state.thickness).extended(by: -rightSidePadding)
            let sideOuterTopUnderside1 = sideInnerTopUnderside1 + sidePaddingHorizontal1

            let sideInnerTopOverside1 = sideInnerTopUnderside1 + sideNormal.scaled(by: state.thickness)
            let sideOuterTopOverside1 = sideOuterTopUnderside1 + sideNormal.scaled(by: state.thickness)

            let sideInnerTopNeutral1 = sideInnerTopUnderside1 + sideNormal.scaled(by: state.thickness * state.kFactor)
            let sideOuterTopNeutral1 = sideOuterTopUnderside1 + sideNormal.scaled(by: state.thickness * state.kFactor)

            let sideOuterBottomUnderside0 = bottomInsideEdge.vertex0 + straightLeft.scaled(by: state.thickness)
            let sideOuterBottomUnderside1 = bottomInsideEdge.vertex1 - straightLeft.scaled(by: state.thickness - rightSidePadding)

            let sideOuterBottomOverside0 = sideOuterBottomUnderside0 + sideNormal.scaled(by: state.thickness)
            let sideOuterBottomOverside1 = sideOuterBottomUnderside1 + sideNormal.scaled(by: state.thickness)

            let sideOuterBottomNeutral0 = sideOuterBottomUnderside0 + sideNormal.scaled(by: state.thickness * state.kFactor)
            let sideOuterBottomNeutral1 = sideOuterBottomUnderside1 + sideNormal.scaled(by: state.thickness * state.kFactor)

            Decoration(color: .red, hidden: true) {
                // top plane
                Decoration(lineStyle: .bendDash) {
                    LineSection(from: topUndersideEdge.vertex0,
                                to: topUndersideEdge.vertex1)

                    Decoration(color: .cyan) {
                        LineSection(from: topUndersideEdge.vertex0 + planeNormal.scaled(by: state.thickness * state.kFactor),
                                    to: topUndersideEdge.vertex1 + planeNormal.scaled(by: state.thickness * state.kFactor))
                    }

                    LineSection(from: topUndersideEdge.vertex0 + planeNormal.scaled(by: state.thickness),
                                to: topUndersideEdge.vertex1 + planeNormal.scaled(by: state.thickness))
                }

                // left bend
                Orbit(pivot: topUndersideEdge.vertex0 + relativePivotPoint, point: topUndersideEdge.vertex0, rotation: bendRotationDown, spokes: false)

                Decoration(color: .cyan) {
                    Orbit(pivot: topUndersideEdge.vertex0 + relativePivotPoint, point: topUndersideEdge.vertex0 + planeNormal.scaled(by: state.thickness * state.kFactor), rotation: bendRotationDown, spokes: false)
                }

                Orbit(pivot: topUndersideEdge.vertex0 + relativePivotPoint, point: topUndersideEdge.vertex0 + planeNormal.scaled(by: state.thickness), rotation: bendRotationDown, spokes: false)

                Orbit(pivot: topUndersideEdge.vertex1 + relativePivotPoint, point: topUndersideEdge.vertex1, rotation: bendRotationDown, spokes: false)

                // right bend
                Decoration(color: .cyan) {
                    Orbit(pivot: topUndersideEdge.vertex1 + relativePivotPoint, point: topUndersideEdge.vertex1 + planeNormal.scaled(by: state.thickness * state.kFactor), rotation: bendRotationDown, spokes: false)
                }

                Orbit(pivot: topUndersideEdge.vertex1 + relativePivotPoint, point: topUndersideEdge.vertex1 + planeNormal.scaled(by: state.thickness), rotation: bendRotationDown, spokes: false)

                // bend bottom inside corners
                Decoration(lineStyle: .dashed()) {
                    LineSection(from: sideInnerTopUnderside0, to: sideInnerTopOverside0)
                    LineSection(from: sideInnerTopUnderside1, to: sideInnerTopOverside1)

                    LineSection(from: topUndersideEdge.vertex0, to: topUndersideEdge.vertex0 + planeNormal.scaled(by: state.thickness))
                    LineSection(from: topUndersideEdge.vertex1, to: topUndersideEdge.vertex1 + planeNormal.scaled(by: state.thickness))
                }

                // side top bend line
                Decoration(lineStyle: .bendDash) {
                    LineSection(from: sideInnerTopUnderside0, to: sideInnerTopUnderside1)
                    Decoration(color: .cyan) {
                        LineSection(from: sideInnerTopNeutral0, to: sideInnerTopNeutral1)
                    }
                    LineSection(from: sideInnerTopOverside0, to: sideInnerTopOverside1)
                }

                // left side extension
                LineSection(from: sideInnerTopUnderside0, to: sideOuterTopUnderside0)
                Decoration(color: .cyan) {
                    LineSection(from: sideInnerTopNeutral0, to: sideOuterTopNeutral0)
                }
                LineSection(from: sideInnerTopOverside0, to: sideOuterTopOverside0)

                // right side extension
                LineSection(from: sideInnerTopUnderside1, to: sideOuterTopUnderside1)
                Decoration(color: .cyan) {
                    LineSection(from: sideInnerTopNeutral1, to: sideOuterTopNeutral1)
                }
                LineSection(from: sideInnerTopOverside1, to: sideOuterTopOverside1)

                // side extension edge left
                LineSection(from: sideOuterTopUnderside0, to: sideOuterTopOverside0)

                // side extension edge right
                LineSection(from: sideOuterTopUnderside1, to: sideOuterTopOverside1)

                // outside to down left
                LineSection(from: sideOuterTopUnderside0, to: sideOuterBottomUnderside0)
                Decoration(color: .cyan) {
                    LineSection(from: sideOuterTopNeutral0, to: sideOuterBottomNeutral0)
                }
                LineSection(from: sideOuterTopOverside0, to: sideOuterBottomOverside0)

                // outside to down right
                LineSection(from: sideOuterTopUnderside1, to: sideOuterBottomUnderside1)
                Decoration(color: .cyan) {
                    LineSection(from: sideOuterTopNeutral1, to: sideOuterBottomNeutral1)
                }
                LineSection(from: sideOuterTopOverside1, to: sideOuterBottomOverside1)

                // bottom corner edge
                LineSection(from: sideOuterBottomUnderside0, to: sideOuterBottomOverside0)
                LineSection(from: sideOuterBottomUnderside1, to: sideOuterBottomOverside1)

                // bottom long edge
                LineSection(from: sideOuterBottomUnderside0, to: sideOuterBottomUnderside1)
                Decoration(color: .cyan) {
                    LineSection(from: sideOuterBottomNeutral0, to: sideOuterBottomNeutral1)
                }
                LineSection(from: sideOuterBottomOverside0, to: sideOuterBottomOverside1)
            }

            let insideBendAllowence = state.bendRadius * bendAngle
            let oversideBendAllowence = (state.bendRadius + state.thickness) * bendAngle
            let neutralBendAllowence = (state.bendRadius + state.thickness * state.kFactor) * bendAngle

            let backRotation = simd_slerp(.identity, bendRotationDown.inverse, state.angleSlerp)

            let undersideBendAllowenceAlongPlane = edgeNormal.scaled(by: insideBendAllowence)
            let oversideBendAllowenceAlongPlane = edgeNormal.scaled(by: oversideBendAllowence)
            let neutralBendAllowenceAlongPlane = edgeNormal.scaled(by: neutralBendAllowence)

            let backrotatedPivotPoint = topUndersideEdge.vertex0 + relativePivotPoint

            // underside
            let sideInnerTopUnderside0Rotated = sideInnerTopUnderside0.rotated(by: backRotation, pivot: backrotatedPivotPoint) + undersideBendAllowenceAlongPlane
            let sideOuterTopUnderside0Rotated = sideOuterTopUnderside0.rotated(by: backRotation, pivot: backrotatedPivotPoint) + undersideBendAllowenceAlongPlane

            let sideInnerTopUnderside1Rotated = sideInnerTopUnderside1.rotated(by: backRotation, pivot: backrotatedPivotPoint) + undersideBendAllowenceAlongPlane
            let sideOuterTopUnderside1Rotated = sideOuterTopUnderside1.rotated(by: backRotation, pivot: backrotatedPivotPoint) + undersideBendAllowenceAlongPlane

            let sideOuterBottomUnderside0Rotated = sideOuterBottomUnderside0.rotated(by: backRotation, pivot: backrotatedPivotPoint) + undersideBendAllowenceAlongPlane
            let sideOuterBottomUnderside1Rotated = sideOuterBottomUnderside1.rotated(by: backRotation, pivot: backrotatedPivotPoint) + undersideBendAllowenceAlongPlane

            // neutral
            let sideInnerTopNeutral0Rotated = sideInnerTopNeutral0.rotated(by: backRotation, pivot: backrotatedPivotPoint) + neutralBendAllowenceAlongPlane
            let sideOuterTopNeutral0Rotated = sideOuterTopNeutral0.rotated(by: backRotation, pivot: backrotatedPivotPoint) + neutralBendAllowenceAlongPlane

            let sideInnerTopNeutral1Rotated = sideInnerTopNeutral1.rotated(by: backRotation, pivot: backrotatedPivotPoint) + neutralBendAllowenceAlongPlane
            let sideOuterTopNeutral1Rotated = sideOuterTopNeutral1.rotated(by: backRotation, pivot: backrotatedPivotPoint) + neutralBendAllowenceAlongPlane

            let sideOuterBottomNeutral0Rotated = sideOuterBottomNeutral0.rotated(by: backRotation, pivot: backrotatedPivotPoint) + neutralBendAllowenceAlongPlane
            let sideOuterBottomNeutral1Rotated = sideOuterBottomNeutral1.rotated(by: backRotation, pivot: backrotatedPivotPoint) + neutralBendAllowenceAlongPlane

            // overside
            let sideOuterBottomOverside0Rotated = sideOuterBottomOverside0.rotated(by: backRotation, pivot: backrotatedPivotPoint) + oversideBendAllowenceAlongPlane
            let sideOuterBottomOverside1Rotated = sideOuterBottomOverside1.rotated(by: backRotation, pivot: backrotatedPivotPoint) + oversideBendAllowenceAlongPlane

            let sideInnerTopOverside0Rotated = sideInnerTopOverside0.rotated(by: backRotation, pivot: backrotatedPivotPoint) + oversideBendAllowenceAlongPlane
            let sideOuterTopOverside0Rotated = sideOuterTopOverside0.rotated(by: backRotation, pivot: backrotatedPivotPoint) + oversideBendAllowenceAlongPlane

            let sideInnerTopOverside1Rotated = sideInnerTopOverside1.rotated(by: backRotation, pivot: backrotatedPivotPoint) + oversideBendAllowenceAlongPlane
            let sideOuterTopOverside1Rotated = sideOuterTopOverside1.rotated(by: backRotation, pivot: backrotatedPivotPoint) + oversideBendAllowenceAlongPlane

            let lidUndersideCorner0Rotated = topUndersideEdge.vertex0
            let lidUndersideCorner1Rotated = topUndersideEdge.vertex1

            let lidOversideCorner0Rotated = topUndersideEdge.vertex0 + planeNormal.scaled(by: state.thickness)
            let lidOversideCorner1Rotated = topUndersideEdge.vertex1 + planeNormal.scaled(by: state.thickness)

            let lidNeutralCorner0Rotated = topUndersideEdge.vertex0 + planeNormal.scaled(by: state.thickness * state.kFactor)
            let lidNeutralCorner1Rotated = topUndersideEdge.vertex1 + planeNormal.scaled(by: state.thickness * state.kFactor)

            Decoration(color: .blue, hidden: true) {
                // top plane
                Decoration(lineStyle: .bendDash) {
                    LineSection(from: lidUndersideCorner0Rotated, to: lidUndersideCorner1Rotated)
                    Decoration(color: .green) {
                        LineSection(from: lidNeutralCorner0Rotated, to: lidNeutralCorner1Rotated)
                    }
                    LineSection(from: lidOversideCorner0Rotated, to: lidOversideCorner1Rotated)
                }

                // bend allowance
                LineSection(from: lidUndersideCorner0Rotated, to: sideInnerTopUnderside0Rotated)
                LineSection(from: lidUndersideCorner1Rotated, to: sideInnerTopUnderside1Rotated)
                Decoration(color: .green) {
                    LineSection(from: lidNeutralCorner0Rotated, to: sideInnerTopNeutral0Rotated)
                    LineSection(from: lidNeutralCorner1Rotated, to: sideInnerTopNeutral1Rotated)
                }
                LineSection(from: lidOversideCorner0Rotated, to: sideInnerTopOverside0Rotated)
                LineSection(from: lidOversideCorner1Rotated, to: sideInnerTopOverside1Rotated)

                // bend allowance bend line
                Decoration(lineStyle: .bendDash) {
                    LineSection(from: sideInnerTopUnderside0Rotated, to: sideInnerTopUnderside1Rotated)
                    Decoration(color: .green) {
                        LineSection(from: sideInnerTopNeutral0Rotated, to: sideInnerTopNeutral1Rotated)
                    }
                    LineSection(from: sideInnerTopOverside0Rotated, to: sideInnerTopOverside1Rotated)
                }

                // side extensions
                LineSection(from: sideInnerTopUnderside0Rotated, to: sideOuterTopUnderside0Rotated)
                LineSection(from: sideInnerTopUnderside1Rotated, to: sideOuterTopUnderside1Rotated)
                Decoration(color: .green) {
                    LineSection(from: sideInnerTopNeutral0Rotated, to: sideOuterTopNeutral0Rotated)
                    LineSection(from: sideInnerTopNeutral1Rotated, to: sideOuterTopNeutral1Rotated)
                }
                LineSection(from: sideInnerTopOverside0Rotated, to: sideOuterTopOverside0Rotated)
                LineSection(from: sideInnerTopOverside1Rotated, to: sideOuterTopOverside1Rotated)

                // to side bottom
                LineSection(from: sideOuterTopUnderside0Rotated, to: sideOuterBottomUnderside0Rotated)
                LineSection(from: sideOuterTopUnderside1Rotated, to: sideOuterBottomUnderside1Rotated)
                Decoration(color: .green) {
                    LineSection(from: sideOuterTopNeutral0Rotated, to: sideOuterBottomNeutral0Rotated)
                    LineSection(from: sideOuterTopNeutral1Rotated, to: sideOuterBottomNeutral1Rotated)
                }
                LineSection(from: sideOuterTopOverside0Rotated, to: sideOuterBottomOverside0Rotated)
                LineSection(from: sideOuterTopOverside1Rotated, to: sideOuterBottomOverside1Rotated)

                // bottom edge
                LineSection(from: sideOuterBottomUnderside0Rotated, to: sideOuterBottomUnderside1Rotated)
                Decoration(color: .green) {
                    LineSection(from: sideOuterBottomNeutral0Rotated, to: sideOuterBottomNeutral1Rotated)
                }
                LineSection(from: sideOuterBottomOverside0Rotated, to: sideOuterBottomOverside1Rotated)
            }
            let projectionRotation = Quat(from: planeNormal, to: Vector(0, 0, 1))

            let sideInnerTopUnderside0Projected = sideInnerTopUnderside0Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
            let sideOuterTopUnderside0Projected = sideOuterTopUnderside0Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
            let sideInnerTopUnderside1Projected = sideInnerTopUnderside1Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
            let sideOuterTopUnderside1Projected = sideOuterTopUnderside1Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
            let sideOuterBottomUnderside0Projected = sideOuterBottomUnderside0Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
            let sideOuterBottomUnderside1Projected = sideOuterBottomUnderside1Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
            let lidUndersideCorner0Projected = lidUndersideCorner0Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
            let lidUndersideCorner1Projected = lidUndersideCorner1Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))

            let sideInnerTopOverside0Projected = sideInnerTopOverside0Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
            let sideOuterTopOverside0Projected = sideOuterTopOverside0Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
            let sideInnerTopOverside1Projected = sideInnerTopOverside1Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
            let sideOuterTopOverside1Projected = sideOuterTopOverside1Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
            let sideOuterBottomOverside0Projected = sideOuterBottomOverside0Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
            let sideOuterBottomOverside1Projected = sideOuterBottomOverside1Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
            let lidOversideCorner0Projected = lidOversideCorner0Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
            let lidOversideCorner1Projected = lidOversideCorner1Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))

            let sideInnerTopNeutral0Projected = sideInnerTopNeutral0Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
            let sideOuterTopNeutral0Projected = sideOuterTopNeutral0Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
            let sideInnerTopNeutral1Projected = sideInnerTopNeutral1Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
            let sideOuterTopNeutral1Projected = sideOuterTopNeutral1Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
            let sideOuterBottomNeutral0Projected = sideOuterBottomNeutral0Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
            let sideOuterBottomNeutral1Projected = sideOuterBottomNeutral1Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
            let lidNeutralCorner0Projected = lidNeutralCorner0Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
            let lidNeutralCorner1Projected = lidNeutralCorner1Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))

            let bendAllowenceMid0 = lidNeutralCorner0Projected + (sideInnerTopNeutral0Projected - lidNeutralCorner0Projected) * 0.5
            let bendAllowenceMid1 = lidNeutralCorner1Projected + (sideInnerTopNeutral1Projected - lidNeutralCorner1Projected) * 0.5

            TextString(center: sideOuterBottomNeutral0Projected + (sideOuterBottomNeutral1Projected - sideOuterBottomNeutral0Projected).scaled(by: 0.5),
                       text: "\(bendRotationDown.angle.radiansToDegrees.toFixed(4))°", size: 12)

            Decoration(hidden: false) {
                // top plane
                Decoration(lineStyle: .bendDash) {
                    LineSection(from: lidNeutralCorner0Projected, to: lidNeutralCorner1Projected)
                }

                /*
                 Decoration(color: .blue) {
                     LineSection(from: bendAllowenceMid0, to: bendAllowenceMid1)
                     let bendLineDirection = (bendAllowenceMid1 - bendAllowenceMid0).normalized
                     let rotation = Quat(pointA: lidNeutralCorner0Projected, pivot: bendAllowenceMid0, pointB: bendAllowenceMid0 + bendLineDirection)
                     Arrow(vector: bendLineDirection.scaled(by: 10), origo: bendAllowenceMid0)
                     Arrow(vector: rotation.axis.scaled(by: 5), origo: bendAllowenceMid0)
                     Orbit(pivot: bendAllowenceMid0, point: lidNeutralCorner0Projected, rotation: rotation, spokes: true)
                 }
                  */

                // bend allowance
                LineSection(from: lidNeutralCorner0Projected, to: sideInnerTopNeutral0Projected)
                LineSection(from: lidNeutralCorner1Projected, to: sideInnerTopNeutral1Projected)

                // bend allowance bend line
                Decoration(lineStyle: .bendDash) {
                    LineSection(from: sideInnerTopNeutral0Projected, to: sideInnerTopNeutral1Projected)
                }

                // side extensions
                LineSection(from: sideInnerTopNeutral0Projected, to: sideOuterTopNeutral0Projected)
                LineSection(from: sideInnerTopNeutral1Projected, to: sideOuterTopNeutral1Projected)

                // to side bottom
                LineSection(from: sideOuterTopNeutral0Projected, to: sideOuterBottomNeutral0Projected)
                LineSection(from: sideOuterTopNeutral1Projected, to: sideOuterBottomNeutral1Projected)

                // bottom edge
                LineSection(from: sideOuterBottomNeutral0Projected, to: sideOuterBottomNeutral1Projected)
            }
        }
    }
}
