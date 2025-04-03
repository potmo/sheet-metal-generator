import AppKit
import CanvasRender
import Cocoa
import Combine
import Foundation
import simd
import SwiftUI

public struct FromSidesView: ShapeMaker {
    public typealias StateType = InputState

    public init() {
    }

    @CanvasBuilder
    public func shapes(from state: StateType) -> [DrawableShape] {
        // LineSection(from: Vector(), to: Vector(100, 0, 0))
        let state = state.frozen
        Decoration(hidden: true) {
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
        }

        // let xAxisRotation = Quat(angle: state.angleAroundX.degreesToRadians, axis: Vector(1, 0, 0))
        // let yAxisRotation = Quat(angle: state.angleAroundY.degreesToRadians, axis: Vector(0, 1, 0))
        // let localYAxis = xAxisRotation.act(Vector(0, 1, 0))
        // let localXAxis = yAxisRotation.act(Vector(1, 0, 0))
        // let planeNormal = localXAxis.cross(localYAxis).normalized

        let planeNormal = state.topFaceNormal

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
        }

        let bendAngles = bendRotations.map { bendRotation in
            bendRotation.angle
        }

        let bottomOutline = innerOutline.map { vertice in vertice.with(z: -state.height) }
        let bottomOutlinePlane = Plane(vertices: bottomOutline)

        let insideSetbacks = bendAngles.map { bendAngle in
            return Bend.insideSetback(angle: bendAngle,
                                      radius: state.bendRadius)
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

        for (index, _) in prescaledPlane.edges.enumerated() {
            let bendAngle = bendAngles[index]

            let sideNormal = sideNormals[index]

            let topUndersideEdge = topUndersidePlane.edges[index]
            let bottomInsideEdge = bottomOutlinePlane.edges[index]

            let relativePivotPoint = planeNormal.scaled(by: -state.bendRadius)

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

            Decoration(color: .red, hidden: !state.showFolded) {
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
                OrbitCounterClockwise(pivot: topUndersideEdge.vertex0 + relativePivotPoint, point: topUndersideEdge.vertex0, rotation: bendRotationDown, spokes: false)

                Decoration(color: .cyan) {
                    OrbitCounterClockwise(pivot: topUndersideEdge.vertex0 + relativePivotPoint, point: topUndersideEdge.vertex0 + planeNormal.scaled(by: state.thickness * state.kFactor), rotation: bendRotationDown, spokes: false)
                }

                OrbitCounterClockwise(pivot: topUndersideEdge.vertex0 + relativePivotPoint, point: topUndersideEdge.vertex0 + planeNormal.scaled(by: state.thickness), rotation: bendRotationDown, spokes: false)

                OrbitCounterClockwise(pivot: topUndersideEdge.vertex1 + relativePivotPoint, point: topUndersideEdge.vertex1, rotation: bendRotationDown, spokes: false)

                // right bend
                Decoration(color: .cyan) {
                    OrbitCounterClockwise(pivot: topUndersideEdge.vertex1 + relativePivotPoint, point: topUndersideEdge.vertex1 + planeNormal.scaled(by: state.thickness * state.kFactor), rotation: bendRotationDown, spokes: false)
                }

                OrbitCounterClockwise(pivot: topUndersideEdge.vertex1 + relativePivotPoint, point: topUndersideEdge.vertex1 + planeNormal.scaled(by: state.thickness), rotation: bendRotationDown, spokes: false)

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

            Decoration(color: .blue, hidden: !state.showTopAlignedFlatView) {
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

//            let sideInnerTopUnderside0Projected = sideInnerTopUnderside0Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
//            let sideOuterTopUnderside0Projected = sideOuterTopUnderside0Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
//            let sideInnerTopUnderside1Projected = sideInnerTopUnderside1Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
//            let sideOuterTopUnderside1Projected = sideOuterTopUnderside1Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
//            let sideOuterBottomUnderside0Projected = sideOuterBottomUnderside0Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
//            let sideOuterBottomUnderside1Projected = sideOuterBottomUnderside1Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
//            let lidUndersideCorner0Projected = lidUndersideCorner0Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
//            let lidUndersideCorner1Projected = lidUndersideCorner1Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))

//            let sideInnerTopOverside0Projected = sideInnerTopOverside0Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
//            let sideOuterTopOverside0Projected = sideOuterTopOverside0Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
//            let sideInnerTopOverside1Projected = sideInnerTopOverside1Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
//            let sideOuterTopOverside1Projected = sideOuterTopOverside1Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
//            let sideOuterBottomOverside0Projected = sideOuterBottomOverside0Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
//            let sideOuterBottomOverside1Projected = sideOuterBottomOverside1Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
//            let lidOversideCorner0Projected = lidOversideCorner0Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
//            let lidOversideCorner1Projected = lidOversideCorner1Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))

            let sideInnerTopNeutral0Projected = sideInnerTopNeutral0Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
            let sideOuterTopNeutral0Projected = sideOuterTopNeutral0Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
            let sideInnerTopNeutral1Projected = sideInnerTopNeutral1Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
            let sideOuterTopNeutral1Projected = sideOuterTopNeutral1Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
            let sideOuterBottomNeutral0Projected = sideOuterBottomNeutral0Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
            let sideOuterBottomNeutral1Projected = sideOuterBottomNeutral1Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
            let lidNeutralCorner0Projected = lidNeutralCorner0Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))
            let lidNeutralCorner1Projected = lidNeutralCorner1Rotated.rotated(by: projectionRotation, pivot: Vector(0, 0, 0))

//            let bendAllowenceMid0 = lidNeutralCorner0Projected + (sideInnerTopNeutral0Projected - lidNeutralCorner0Projected) * 0.5
//            let bendAllowenceMid1 = lidNeutralCorner1Projected + (sideInnerTopNeutral1Projected - lidNeutralCorner1Projected) * 0.5

            Decoration(color: .black, hidden: !state.showHorizontalFlatView) {
                // top plane

                /*
                 Decoration(lineStyle: .bendDash) {
                 LineSection(from: lidNeutralCorner0Projected, to: lidNeutralCorner1Projected)
                 }
                 */

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

                let halfBendAllowanceMid = (sideInnerTopNeutral0Projected - lidNeutralCorner0Projected).scaled(by: 0.5)
                let radius = halfBendAllowanceMid.length
                let bendAllowanceCutout0 = lidNeutralCorner0Projected + halfBendAllowanceMid
                let bendAllowanceCutout1 = lidNeutralCorner1Projected + halfBendAllowanceMid
                let bendAllowanceMid = lidNeutralCorner1Projected + (lidNeutralCorner0Projected - lidNeutralCorner1Projected).scaled(by: 0.5) + halfBendAllowanceMid
                let right = (lidNeutralCorner1Projected - lidNeutralCorner0Projected).normalized
                let tabSize = 2.0
                // left radius
                AxisOrbitCounterClockwise(pivot: bendAllowanceCutout0, point: sideInnerTopNeutral0Projected,
                                          angle: .pi,
                                          axis: Vector(0, 0, -1))

                AxisOrbitCounterClockwise(pivot: bendAllowanceCutout0 + right.scaled(by: tabSize + radius * 2),
                                          point: bendAllowanceCutout0 + halfBendAllowanceMid + right.scaled(by: tabSize + radius * 2),
                                          angle: .pi,
                                          axis: Vector(0, 0, 1))

                LineSection(from: bendAllowanceCutout0 + halfBendAllowanceMid + right.scaled(by: tabSize + radius * 2),
                            to: bendAllowanceMid + halfBendAllowanceMid - right.scaled(by: tabSize / 2 + radius))
                LineSection(from: bendAllowanceCutout0 - halfBendAllowanceMid + right.scaled(by: tabSize + radius * 2),
                            to: bendAllowanceMid - halfBendAllowanceMid - right.scaled(by: tabSize / 2 + radius))

                // mid radius


                Decoration(color: .red) {
                    AxisOrbitCounterClockwise(pivot: bendAllowanceMid + right.scaled(by: tabSize / 2 + radius),
                                              point: bendAllowanceMid + halfBendAllowanceMid + right.scaled(by: tabSize / 2 + radius),
                                              angle: .pi,
                                              axis: Vector(0, 0, 1))

                    AxisOrbitCounterClockwise(pivot: bendAllowanceMid - right.scaled(by: tabSize / 2 + radius),
                                              point: bendAllowanceMid + halfBendAllowanceMid - right.scaled(by: tabSize / 2 + radius),
                                              angle: .pi,
                                              axis: Vector(0, 0, -1))
                }

                LineSection(from: bendAllowanceMid + halfBendAllowanceMid + right.scaled(by: tabSize / 2 + radius),
                            to: bendAllowanceCutout1 + halfBendAllowanceMid - right.scaled(by: tabSize + radius * 2))
                LineSection(from: bendAllowanceMid - halfBendAllowanceMid + right.scaled(by: tabSize / 2 + radius),
                            to: bendAllowanceCutout1 - halfBendAllowanceMid - right.scaled(by: tabSize + radius * 2))

                // right view

                AxisOrbitCounterClockwise(pivot: bendAllowanceCutout1,
                                          point: sideInnerTopNeutral1Projected,
                                          angle: .pi,
                                          axis: Vector(0, 0, 1))

                AxisOrbitCounterClockwise(pivot: bendAllowanceCutout1 - right.scaled(by: tabSize + radius * 2),
                                          point: bendAllowanceCutout1 + halfBendAllowanceMid - right.scaled(by: tabSize + radius * 2),
                                          angle: .pi,
                                          axis: Vector(0, 0, -1))

                // bend allowance bend line

                Decoration(color: .red, lineStyle: .bendDash, hidden: true) {
                    LineSection(from: sideInnerTopNeutral0Projected, to: sideInnerTopNeutral1Projected)
                }

                // side extensions

                LineSection(from: sideInnerTopNeutral0Projected, to: sideOuterTopNeutral0Projected)
                LineSection(from: sideInnerTopNeutral1Projected, to: sideOuterTopNeutral1Projected)

                let sideLegVector0 = sideOuterBottomNeutral0Projected - sideOuterTopNeutral0Projected
                let sideLegVector1 = sideOuterBottomNeutral1Projected - sideOuterTopNeutral1Projected
                if sideLegVector0.normalized.dot(sideNormal) <= 0 {
                    CodeBlock { _ in
                       // fatalError("warning: side inverted with: \(sideLegVector0.length)")
                    }
                }

                if sideLegVector0.length <= 10 {
                    CodeBlock { _ in
                      //  fatalError("warning: side too short: \(sideLegVector0.length)")
                    }
                }

                if sideLegVector1.normalized.dot(sideNormal) <= 0 {
                    CodeBlock { _ in
                      //  fatalError("warning: side inverted  with: \(sideLegVector1.length)")
                    }
                }

                if sideLegVector1.length <= 10 {
                    CodeBlock { _ in
                      //  fatalError("warning: side too short: \(sideLegVector1.length)")
                    }
                }

                // to side bottom

                LineSection(from: sideOuterTopNeutral0Projected, to: sideOuterBottomNeutral0Projected)

                LineSection(from: sideOuterTopNeutral1Projected, to: sideOuterBottomNeutral1Projected)

                // bottom edge
                Decoration(color: .red) {
                    //  Arrow(from: sideOuterBottomNeutral0Projected, to: sideOuterBottomNeutral1Projected)
                }

                /*
                 let maxBits = 12 // max value 8191
                 // let number = min(6435, (1 << maxBits) - 1)

                 // just use the aligning bits for all sides but one
                 let number = index == 2 ? 0b1101_1100_0000 : 0b0000_0000_0000

                 // get the bits and then split the bits so its up-down for 0 and down up for 1
                 let upsAndDowns = (0 ..< maxBits)
                     .map { maxBits - $0 - 1 }
                     .map { bit($0, of: number) }
                     .reversed()
                     .map { $0 }

                 // .flatMap { $0 ? [true, false] : [false, true] } // double so 1 bit is 10 and 0 is 01 so they dont fit oneanother
                  */

                let start = sideOuterBottomNeutral0Projected
                let end = sideOuterBottomNeutral1Projected
                let dir = (end - start).normalized

                let perpDir = Vector(0, 0, 1).cross(dir)

                // comment this back if you want to have real bits
                // let firstBits = [false, true, false] + Array(upsAndDowns[0 ..< (upsAndDowns.count / 2)]) + [false]
                // let secondBits = [false] + Array(upsAndDowns[(upsAndDowns.count / 2) ..< upsAndDowns.count]) + [false, true, false]

                let fullWidth = (end - start).length

                // add label
                if index == 0 {
                    PathNumber(number: state.firstLabel,
                               topCorner: start + dir.scaled(by: fullWidth / 2.0 - 5 * 0.8 * 5 / 2) - perpDir.scaled(by: 3.0),
                               sideDirection: dir,
                               downDirection: -perpDir,
                               scale: 5.0,
                               spacing: 0.8)
                }

                // offset everything to take account for the side overlap
                let fastenerStart = if index == 0 || index == 2 { // up, down
                    start +
                        dir.scaled(by: fullWidth / 2 - state.fastenerWidth / 2) +
                        dir.scaled(by: state.thickness * state.gapScalar * 0.5)
                } else if index == 1 || index == 3 { // left, right side
                    start +
                        dir.scaled(by: fullWidth / 2 - state.hookWidth / 2) +
                        dir.scaled(by: state.thickness * state.gapScalar * 0.5)
                } else {
                    fatalError("wrong index")
                }

                let fastenerEnd = if index == 0 || index == 2 { // up, down
                    start +
                        dir.scaled(by: fullWidth / 2 + state.fastenerWidth / 2) +
                        dir.scaled(by: state.thickness * state.gapScalar * 0.5)
                } else if index == 1 || index == 3 { // left, right side
                    start +
                        dir.scaled(by: fullWidth / 2 + state.hookWidth / 2) +
                        dir.scaled(by: state.thickness * state.gapScalar * 0.5)
                } else {
                    fatalError("wrong index")
                }

                let toothReliefRadius = state.toothReliefRadius
                let toothReliefDepth = state.toothReliefDepth

                // hole tabs
                Decoration(hidden: index != 0 && index != 2) {
                    CanvasRender.Path {
                        MoveTo(start)

                        LineTo(fastenerStart - dir.scaled(by: toothReliefRadius * 2))
                        LineTo(fastenerStart - dir.scaled(by: toothReliefRadius * 2) - perpDir.scaled(by: toothReliefDepth))
                        AxisOrbitCounterClockwise(pivot: fastenerStart - dir.scaled(by: toothReliefRadius) - perpDir.scaled(by: toothReliefDepth),
                                                  point: fastenerStart - dir.scaled(by: toothReliefRadius * 2) - perpDir.scaled(by: toothReliefDepth),
                                                  angle: .pi,
                                                  axis: Vector(0, 0, 1))

                        // fastener tab
                        LineTo(fastenerStart)
                        LineTo(fastenerStart + perpDir.scaled(by: state.thickness + state.fastenerExtraHeight))

                        AxisOrbitCounterClockwise(pivot: fastenerStart + perpDir.scaled(by: state.thickness + state.fastenerExtraHeight) + dir.scaled(by: state.toothKeyRoundingRadius),
                                                  point: fastenerStart + perpDir.scaled(by: state.thickness + state.fastenerExtraHeight),
                                                  angle: .pi * 0.5, axis: Vector(0, 0, -1))

                        LineTo(fastenerEnd + perpDir.scaled(by: state.thickness + state.fastenerExtraHeight + state.toothKeyRoundingRadius) - dir.scaled(by: state.toothKeyRoundingRadius))

                        AxisOrbitCounterClockwise(pivot: fastenerEnd + perpDir.scaled(by: state.thickness + state.fastenerExtraHeight) - dir.scaled(by: state.toothKeyRoundingRadius),
                                                  point: fastenerEnd + perpDir.scaled(by: state.thickness + state.fastenerExtraHeight + state.toothKeyRoundingRadius) - dir.scaled(by: state.toothKeyRoundingRadius),
                                                  angle: .pi * 0.5, axis: Vector(0, 0, -1))

                        LineTo(fastenerEnd + perpDir.scaled(by: state.thickness + state.fastenerExtraHeight))
                        LineTo(fastenerEnd)

                        LineTo(fastenerEnd - perpDir.scaled(by: toothReliefDepth))

                        AxisOrbitCounterClockwise(pivot: fastenerEnd + dir.scaled(by: toothReliefRadius) - perpDir.scaled(by: toothReliefDepth),
                                                  point: fastenerEnd - perpDir.scaled(by: toothReliefDepth),
                                                  angle: .pi,
                                                  axis: Vector(0, 0, 1))

                        LineTo(fastenerEnd + dir.scaled(by: toothReliefRadius * 2))

                        LineTo(end)
                    }

                    CanvasRender.Path {
                        let holeMid = fastenerStart + (fastenerEnd - fastenerStart) / 2.0 + perpDir.scaled(by: state.bottomPlateThickness / 2 + state.toothClearence)
                        let holeStart = holeMid + dir.scaled(by: -state.fastenerHoleWidth * 0.5 - state.toothClearence)
                        let holeEnd = holeMid - dir.scaled(by: -state.fastenerHoleWidth * 0.5 - state.toothClearence)

                        RelievedSlot(start: holeStart,
                                     end: holeEnd,
                                     width: -perpDir.scaled(by: state.bottomPlateThickness / 2 + state.toothClearence),
                                     reliefDepth: toothReliefDepth,
                                     reliefRadius: toothReliefRadius)
                    }
                }

                // left and right
                Decoration(hidden: index != 3 && index != 1) {
                    let flip = index == 1

                    Flip(at: start + (end - start).scaled(by: 0.5), around: perpDir, by: flip ? .pi : 0) {
                        CanvasRender.Path {
                            MoveTo(start)

                            Offset(flip ? -dir.scaled(by: state.thickness * state.gapScalar) : Vector(0, 0, 0)) {
                                // hook tab
                                LineTo(fastenerStart + dir.scaled(by: toothReliefRadius))

                                LineTo(fastenerStart + dir.scaled(by: state.hookDepth - toothReliefRadius * 2))

                                LineTo(fastenerStart + dir.scaled(by: state.hookDepth - toothReliefRadius * 2) - perpDir.scaled(by: toothReliefDepth))
                                AxisOrbitCounterClockwise(pivot: fastenerStart + dir.scaled(by: state.hookDepth - toothReliefRadius) - perpDir.scaled(by: toothReliefDepth),
                                                          point: fastenerStart + dir.scaled(by: state.hookDepth - toothReliefRadius * 2) - perpDir.scaled(by: toothReliefDepth),
                                                          angle: .pi,
                                                          axis: Vector(0, 0, 1))

                                LineTo(fastenerStart + perpDir.scaled(by: state.bottomPlateThickness + state.hookIntoSlotOffset - state.toothKeyRoundingRadius) + dir.scaled(by: state.hookDepth))

                                AxisOrbitCounterClockwise(pivot: fastenerStart + perpDir.scaled(by: state.bottomPlateThickness + state.hookIntoSlotOffset - state.toothKeyRoundingRadius) + dir.scaled(by: state.hookDepth) + dir.scaled(by: state.toothKeyRoundingRadius),
                                                          point: fastenerStart + perpDir.scaled(by: state.bottomPlateThickness + state.hookIntoSlotOffset - state.toothKeyRoundingRadius) + dir.scaled(by: state.hookDepth),
                                                          angle: .pi * 0.5,
                                                          axis: Vector(0, 0, -1))

                                LineTo(fastenerEnd + perpDir.scaled(by: state.bottomPlateThickness + state.hookIntoSlotOffset) - dir.scaled(by: state.toothKeyRoundingRadius))

                                AxisOrbitCounterClockwise(pivot: fastenerEnd + perpDir.scaled(by: state.bottomPlateThickness + state.hookIntoSlotOffset - state.toothKeyRoundingRadius) - dir.scaled(by: state.toothKeyRoundingRadius),
                                                          point: fastenerEnd + perpDir.scaled(by: state.bottomPlateThickness + state.hookIntoSlotOffset) - dir.scaled(by: state.toothKeyRoundingRadius),
                                                          angle: .pi * 0.5,
                                                          axis: Vector(0, 0, -1))

                                LineTo(fastenerEnd)

                                LineTo(fastenerEnd - perpDir.scaled(by: toothReliefDepth))

                                AxisOrbitCounterClockwise(pivot: fastenerEnd + dir.scaled(by: toothReliefRadius) - perpDir.scaled(by: toothReliefDepth),
                                                          point: fastenerEnd - perpDir.scaled(by: toothReliefDepth),
                                                          angle: .pi,
                                                          axis: Vector(0, 0, 1))

                                LineTo(fastenerEnd + dir.scaled(by: toothReliefRadius * 2))
                            }

                            LineTo(end)
                        }
                    }
                }
            }
        }
    }

    @PathBuilder
    private func bitTooth(state: InputState.Frozen, bits: [Bool], from start: Vector, to end: Vector, planeNormal: Vector, toothReliefRadius: Double, toothReliefDepth: Double, toothClearence: Double) -> [PartOfPath] {
        let toothWidth = state.thickness * 2.0
        let toothHeight = state.thickness

        let right = (end - start).normalized
        let down = planeNormal.cross(right)
        let toothedWidth = Double(bits.count) * toothWidth
        let fullWidth = (end - start).length
        let emptyPadding = (end - start).normalized.scaled(by: fullWidth - toothedWidth) / 2
        let toothDown = down.scaled(by: toothHeight)

        let toothRadius = toothWidth / 2.0 - toothClearence

        for (index, currentIsDown) in bits.enumerated() {
            let nextIsDown = bits.indices.contains(index + 1) ? bits[index + 1] : false

            let endOffset = start + emptyPadding + right.scaled(by: toothWidth * Double(index + 1))

            switch (currentIsDown, nextIsDown) {
            case (false, true):
                LineTo(endOffset + right.scaled(by: toothClearence) - right.scaled(by: toothReliefRadius * 2))
                LineTo(endOffset + right.scaled(by: toothClearence) - right.scaled(by: toothReliefRadius * 2) - down.scaled(by: toothReliefDepth))
                AxisOrbitCounterClockwise(pivot: endOffset + right.scaled(by: toothClearence) - right.scaled(by: toothReliefRadius) - down.scaled(by: toothReliefDepth),
                                          point: endOffset + right.scaled(by: toothClearence) - right.scaled(by: toothReliefRadius * 2) - down.scaled(by: toothReliefDepth),
                                          angle: .pi,
                                          axis: Vector(0, 0, 1))
                LineTo(endOffset + right.scaled(by: toothClearence) + toothDown)
                AxisOrbitCounterClockwise(pivot: endOffset + right.scaled(by: toothClearence) + toothDown + right.scaled(by: toothRadius),
                                          point: endOffset + right.scaled(by: toothClearence) + toothDown,
                                          angle: .pi * 0.5,
                                          axis: Vector(0, 0, -1))

            case (true, false):
                LineTo(endOffset - right.scaled(by: toothClearence) + toothDown - right.scaled(by: toothRadius) + down.scaled(by: toothRadius))

                AxisOrbitCounterClockwise(pivot: endOffset - right.scaled(by: toothClearence) + toothDown - right.scaled(by: toothRadius),
                                          point: endOffset - right.scaled(by: toothClearence) + toothDown - right.scaled(by: toothRadius) + down.scaled(by: toothRadius),
                                          angle: .pi * 0.5,
                                          axis: Vector(0, 0, -1))

                LineTo(endOffset - right.scaled(by: toothClearence) - down.scaled(by: toothReliefDepth))
                AxisOrbitCounterClockwise(pivot: endOffset - right.scaled(by: toothClearence) - down.scaled(by: toothReliefDepth) + right.scaled(by: toothReliefRadius),
                                          point: endOffset - right.scaled(by: toothClearence) - down.scaled(by: toothReliefDepth),
                                          angle: .pi,
                                          axis: Vector(0, 0, 1))
                LineTo(endOffset - right.scaled(by: toothClearence) + right.scaled(by: toothReliefRadius * 2))

            case (true, true):
                Nothing()

            case (false, false):
                Nothing()
            }
        }
    }

    private func bit(_ n: Int, of num: Int) -> Bool {
        return (num >> n) & 1 == 1
    }
}
