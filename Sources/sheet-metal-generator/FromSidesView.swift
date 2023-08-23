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
        LineSection(from: Vector(), to: Vector(100, 0, 0))

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
        let innerSize = state.size - state.thickness
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

        /*
        Decoration(color: .orange, lineStyle: .dashed()) {
            Polygon(vertices: innerOutline)
        }
        Decoration(color: .indigo, lineStyle: .dashed()) {
            Polygon(vertices: outsideOutline)
        }
         */

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

        let oppositeRotationAngles = [
            eastBendAngle,
            southBendAngle,
            westBendAngle,
            northBendAngle,
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
/*
        Decoration(color: .mint) {
            Arrow(from: Vector(), to: localXAxis.scaled(by: 20))
            Arrow(from: Vector(), to: localYAxis.scaled(by: 20))
        }
        */

        let height = state.size
        let bottomOutline = innerOutline.map { vertice in vertice + Vector(0, 0, -height) }
        let bottomOutlinePlane = Plane(vertices: bottomOutline)

        /*
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

            Decoration(lineStyle: .bendDash) {
                LineSection(from: prescaledPlane.north.middle, to: prescaledPlane.south.middle)
                LineSection(from: prescaledPlane.west.middle, to: prescaledPlane.east.middle)
            }
        }
        */

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

        let sideNormals = [
            Vector(0, 1, 0),
            Vector(1, 0, 0),
            Vector(0, -1, 0),
            Vector(-1, 0, 0),
        ]

        let scaledBottomPlane = prescaledPlane
            .north.resizedAlongSides(by: -insideSetbacks[0])
            .east.resizedAlongSides(by: -insideSetbacks[1])
            .south.resizedAlongSides(by: -insideSetbacks[2])
            .west.resizedAlongSides(by: -insideSetbacks[3])

        let backRotation = Quat(from: scaledBottomPlane.normal, to: Vector(0, 0, 1))
        let backRotatedVertices = scaledBottomPlane.vertices.map { vertex in
            return backRotation.act(vertex) + Vector(state.size * 3, 0, 0)
        }
        let backRotatedPlane = Plane(vertices: backRotatedVertices)

        /* Decoration(color: .red, lineStyle: .bendDash) {
             Polygon(vertices: backRotatedPlane.vertices, closed: true)
         } */

        for (index, edge) in prescaledPlane.edges.enumerated() {
            let bendAngle = bendAngles[index]
            let sideNormal = sideNormals[index]
            let insideSetback = insideSetbacks[index]
            let scaledEdge = scaledBottomPlane.edges[index]
            let bottomEdge = bottomOutlinePlane.edges[index]
            let backRotatedEdge = backRotatedPlane.edges[index]
            let oppositeRotationAngle = oppositeRotationAngles[index]
            let bendAllowance = bendAllowances[index]

            let oppositeBendAngle = Quat(angle: -oppositeRotationAngle, axis: sideNormal)

            let sideUp = oppositeBendAngle.act(Vector(0, 0, 1))
            let sideRight = sideNormal.cross(sideUp)

            let bendRotation = Quat(angle: bendAngle, axis: sideRight)

            // drop is perpendicular to edge
            let drop = edge.middle + sideUp.scaled(by: -insideSetback)
            let lever = sideNormal.scaled(by: -(state.bendRadius))
            let pivotPoint = drop + lever

            let bendPoint = pivotPoint + bendRotation.act(lever.scaled(by: -1))

            let dropRelativeToBendPoint = drop - bendPoint
            let pivotPointRelativeToBendPoint = pivotPoint - bendPoint

            let firstScaledCorner = scaledEdge.middle + scaledEdge.edge.scaled(by: -0.5)
            let secondScaledCorner = scaledEdge.middle + scaledEdge.edge.scaled(by: 0.5)

            let firstFullCorner = edge.vertex0 + Vector(0, 0, 1 / Vector(0, 0, -1).dot(sideUp)).scaled(by: insideSetback)
            let secondFullCorner = edge.vertex1 + Vector(0, 0, 1 / Vector(0, 0, -1).dot(sideUp)).scaled(by: insideSetback)

            let bendArcLength = bendAngle * state.bendRadius

            let kFactorExtension = state.thickness * state.kFactor

            // 3d version

            Decoration(color: .red) {
                Decoration(lineStyle: .bendDash) {
                    LineSection(from: scaledEdge.vertex0, to: scaledEdge.vertex1)
                }

                Decoration(color: .purple) {
                    LineSection(from: firstScaledCorner + pivotPointRelativeToBendPoint,
                                to: firstScaledCorner + pivotPointRelativeToBendPoint + sideNormal.scaled(by: state.thickness + state.bendRadius))

                    Circle(center: firstScaledCorner + pivotPointRelativeToBendPoint, radius: 4)
                }

                Orbit(pivot: firstScaledCorner + pivotPointRelativeToBendPoint,
                      point: firstScaledCorner + dropRelativeToBendPoint,
                      rotation: bendRotation)

                Orbit(pivot: secondScaledCorner + pivotPointRelativeToBendPoint,
                      point: secondScaledCorner + dropRelativeToBendPoint,
                      rotation: bendRotation)

                Decoration(lineStyle: .bendDash) {
                    LineSection(from: firstScaledCorner + dropRelativeToBendPoint, to: secondScaledCorner + dropRelativeToBendPoint)
                }

                LineSection(from: firstFullCorner, to: firstScaledCorner + dropRelativeToBendPoint)
                LineSection(from: secondScaledCorner + dropRelativeToBendPoint, to: secondFullCorner)

                LineSection(from: firstFullCorner, to: firstFullCorner.with(z: -state.height))
                LineSection(from: secondFullCorner, to: secondFullCorner.with(z: -state.height))
                LineSection(from: firstFullCorner.with(z: -state.height), to: secondFullCorner.with(z: -state.height))
            }

            // 3d at neutral exis
            /*
             Decoration(color: .red) {
                 Decoration(lineStyle: .bendDash) {
                     LineSection(from: scaledEdge.vertex0 + prescaledPlane.normal.scaled(by: kFactorExtension),
                                 to: scaledEdge.vertex1 + prescaledPlane.normal.scaled(by: kFactorExtension))
                 }

                 Orbit(pivot: firstScaledCorner + pivotPointRelativeToBendPoint,
                       point: firstScaledCorner + dropRelativeToBendPoint + sideNormal.scaled(by: kFactorExtension),
                       rotation: bendRotation)

                 Orbit(pivot: secondScaledCorner + pivotPointRelativeToBendPoint,
                       point: secondScaledCorner + dropRelativeToBendPoint + sideNormal.scaled(by: kFactorExtension),
                       rotation: bendRotation)

                 Decoration(lineStyle: .bendDash) {
                     LineSection(from: firstScaledCorner + dropRelativeToBendPoint + sideNormal.scaled(by: kFactorExtension),
                                 to: secondScaledCorner + dropRelativeToBendPoint + sideNormal.scaled(by: kFactorExtension))
                 }

                 LineSection(from: firstFullCorner + sideNormal.scaled(by: kFactorExtension),
                             to: firstScaledCorner + dropRelativeToBendPoint + sideNormal.scaled(by: kFactorExtension))
                 LineSection(from: secondScaledCorner + dropRelativeToBendPoint + sideNormal.scaled(by: kFactorExtension),
                             to: secondFullCorner + sideNormal.scaled(by: kFactorExtension))

                 LineSection(from: firstFullCorner + sideNormal.scaled(by: kFactorExtension),
                             to: bottomEdge.vertex0 + sideNormal.scaled(by: kFactorExtension))
                 LineSection(from: secondFullCorner + sideNormal.scaled(by: kFactorExtension),
                             to: bottomEdge.vertex1 + sideNormal.scaled(by: kFactorExtension))
                 LineSection(from: bottomEdge.vertex0 + sideNormal.scaled(by: kFactorExtension),
                             to: bottomEdge.vertex1 + sideNormal.scaled(by: kFactorExtension))
             }
             */

            // 3d opened flaps at neutral axis
            Decoration(color: .black) {
                // extend these (pivotPointRelativeToBendPoint, dropRelativeToBendPoint) by kFactorExtension

                let top1 = firstScaledCorner + dropRelativeToBendPoint + sideNormal.scaled(by: kFactorExtension)
                let top2 = secondScaledCorner + dropRelativeToBendPoint + sideNormal.scaled(by: kFactorExtension)

                let secondOuterBendExtension1 = firstFullCorner + sideNormal.scaled(by: kFactorExtension)
                let secondInnerBendExtension1 = firstScaledCorner + dropRelativeToBendPoint + sideNormal.scaled(by: kFactorExtension)
                let secondOuterBendExtension2 = secondFullCorner + sideNormal.scaled(by: kFactorExtension)
                let secondInnerBendExtension2 = secondScaledCorner + dropRelativeToBendPoint + sideNormal.scaled(by: kFactorExtension)
                let bottomCorner1 = secondOuterBendExtension1.with(z: -state.height)
                let bottomCorner2 = secondOuterBendExtension2.with(z: -state.height)

                let edgeVertex0 = scaledEdge.vertex0 + prescaledPlane.normal.scaled(by: kFactorExtension)
                let edgeVertex1 = scaledEdge.vertex1 + prescaledPlane.normal.scaled(by: kFactorExtension)

                Decoration(color: .blue) {
                    Decoration(lineStyle: .bendDash) {
                        LineSection(from: edgeVertex0,
                                    to: edgeVertex1)
                    }

                    Orbit(pivot: firstScaledCorner + pivotPointRelativeToBendPoint,
                          point: top1,
                          rotation: bendRotation)

                    Orbit(pivot: secondScaledCorner + pivotPointRelativeToBendPoint,
                          point: top2,
                          rotation: bendRotation)

                    Decoration(lineStyle: .bendDash) {
                        LineSection(from: top1, to: top2)
                    }

                    Decoration(lineStyle: .bendDash) {
                        LineSection(from: top1, to: top2)
                    }

                    LineSection(from: secondOuterBendExtension1, to: secondInnerBendExtension1)
                    LineSection(from: secondInnerBendExtension2, to: secondOuterBendExtension2)

                    LineSection(from: secondOuterBendExtension1, to: bottomCorner1)
                    LineSection(from: secondOuterBendExtension2, to: bottomCorner2)
                    LineSection(from: bottomCorner1, to: bottomCorner2)
                }

                let bendAllowanceVector = edge.normal.scaled(by: 0 /* bendAllowance */ )

                let firstPivot = firstScaledCorner + pivotPointRelativeToBendPoint
                let secondPivot = secondScaledCorner + pivotPointRelativeToBendPoint
                let top1Backrotated = top1.rotated(by: bendRotation, pivot: firstPivot) + bendAllowanceVector
                let top2Backrotated = top2.rotated(by: bendRotation, pivot: secondPivot) + bendAllowanceVector

                let secondOuterBendExtension1Backrotated = secondOuterBendExtension1.rotated(by: bendRotation, pivot: firstPivot) + bendAllowanceVector
                let secondInnerBendExtension1Backrotated = secondInnerBendExtension1.rotated(by: bendRotation, pivot: firstPivot) + bendAllowanceVector
                let secondOuterBendExtension2Backrotated = secondOuterBendExtension2.rotated(by: bendRotation, pivot: secondPivot) + bendAllowanceVector
                let secondInnerBendExtension2Backrotated = secondInnerBendExtension2.rotated(by: bendRotation, pivot: secondPivot) + bendAllowanceVector
                let bottomCorner1Backrotated = bottomCorner1.rotated(by: bendRotation, pivot: firstPivot) // + bendAllowanceVector
                let bottomCorner2Backrotated = bottomCorner2.rotated(by: bendRotation, pivot: secondPivot) // + bendAllowanceVector

                let reprojectionRotation = Quat(from: prescaledPlane.normal, to: Vector(0, 0, 1))
                let reprojectionCenter = prescaledPlane.center

                Decoration(color: .clear) {
                    Decoration(lineStyle: .bendDash) {
                        LineSection(from: edgeVertex0,
                                    to: edgeVertex1)
                    }
                    LineSection(from: edgeVertex0,
                                to: top1Backrotated)
                    LineSection(from: edgeVertex1,
                                to: top2Backrotated)

                    Decoration(lineStyle: .bendDash) {
                        LineSection(from: top1Backrotated, to: top2Backrotated)
                    }

                    LineSection(from: secondOuterBendExtension1Backrotated, to: secondInnerBendExtension1Backrotated)
                    LineSection(from: secondInnerBendExtension2Backrotated, to: secondOuterBendExtension2Backrotated)

                    LineSection(from: secondOuterBendExtension1Backrotated, to: bottomCorner1Backrotated)
                    /*
                     LineSection(from: secondOuterBendExtension2Backrotated, to: bottomCorner2Backrotated)
                     LineSection(from: bottomCorner1Backrotated, to: bottomCorner2Backrotated)
                      */
                }

                // reprojected
                let offset = Vector(0, 0, 0)
                let top1Reprojected = top1Backrotated.rotated(by: reprojectionRotation, pivot: reprojectionCenter) + offset
                let top2Reprojected = top2Backrotated.rotated(by: reprojectionRotation, pivot: reprojectionCenter) + offset

                let secondOuterBendExtension1Reprojected = secondOuterBendExtension1Backrotated.rotated(by: reprojectionRotation, pivot: reprojectionCenter) + offset
                let secondInnerBendExtension1Reprojected = secondInnerBendExtension1Backrotated.rotated(by: reprojectionRotation, pivot: reprojectionCenter) + offset
                let secondOuterBendExtension2Reprojected = secondOuterBendExtension2Backrotated.rotated(by: reprojectionRotation, pivot: reprojectionCenter) + offset
                let secondInnerBendExtension2Reprojected = secondInnerBendExtension2Backrotated.rotated(by: reprojectionRotation, pivot: reprojectionCenter) + offset
                let bottomCorner1Reprojected = bottomCorner1Backrotated.rotated(by: reprojectionRotation, pivot: reprojectionCenter) + offset
                let bottomCorner2Reprojected = bottomCorner2Backrotated.rotated(by: reprojectionRotation, pivot: reprojectionCenter) + offset
                let edgeVertex0Reprojected = edgeVertex0.rotated(by: reprojectionRotation, pivot: reprojectionCenter) + offset
                let edgeVertex1Reprojected = edgeVertex1.rotated(by: reprojectionRotation, pivot: reprojectionCenter) + offset

                Decoration(color: .clear) {
                    Decoration(lineStyle: .bendDash) {
                        LineSection(from: edgeVertex0Reprojected,
                                    to: edgeVertex1Reprojected)
                    }
                    LineSection(from: edgeVertex0Reprojected,
                                to: top1Reprojected)
                    LineSection(from: edgeVertex1Reprojected,
                                to: top2Reprojected)

                    Decoration(lineStyle: .bendDash) {
                        LineSection(from: top1Reprojected, to: top2Reprojected)
                    }

                    Decoration(lineStyle: .bendDash) {
                        LineSection(from: top1Reprojected, to: top2Reprojected)
                    }

                    LineSection(from: secondOuterBendExtension1Reprojected, to: secondInnerBendExtension1Reprojected)
                    LineSection(from: secondInnerBendExtension2Reprojected, to: secondOuterBendExtension2Reprojected)

                    LineSection(from: secondOuterBendExtension1Reprojected, to: bottomCorner1Reprojected)
                    LineSection(from: secondOuterBendExtension2Reprojected, to: bottomCorner2Reprojected)
                    LineSection(from: bottomCorner1Reprojected, to: bottomCorner2Reprojected)
                }
            }
        }
    }
}
