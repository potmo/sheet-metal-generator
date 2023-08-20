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

            Decoration(lineStyle: .bendDash) {
                LineSection(from: prescaledPlane.north.middle, to: prescaledPlane.south.middle)
                LineSection(from: prescaledPlane.west.middle, to: prescaledPlane.east.middle)
            }
        }

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

            /*
             Decoration(color: .cyan, lineStyle: .regularDash) {
                 LineSection(from: edge.middle, to: drop)
                 LineSection(from: drop + edge.edge.scaled(by: -0.1), to: drop + edge.edge.scaled(by: 0.1))
                 LineSection(from: drop, to: pivotPoint)
             }

             Decoration(color: .orange) {
                 Circle(center: pivotPoint, radius: 2)
                 Circle(center: drop, radius: 2)
                 Circle(center: bendPoint, radius: 2)
             }
             */

            // 3d version
            Decoration(color: .blue) {
                Decoration(lineStyle: .bendDash) {
                    LineSection(from: scaledEdge.vertex0, to: scaledEdge.vertex1)
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

                LineSection(from: firstFullCorner, to: bottomEdge.vertex0)
                LineSection(from: secondFullCorner, to: bottomEdge.vertex1)
                LineSection(from: bottomEdge.vertex0, to: bottomEdge.vertex1)
            }

            // 3d at neutral exis
            Decoration(color: .red) {
                let kFactorExtension = state.thickness * state.kFactor
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
            /*
             // 3d backrotated flaps
             Decoration(color: .black) {
                 let top1 = firstScaledCorner + dropRelativeToBendPoint
                 let top2 = secondScaledCorner + dropRelativeToBendPoint
                 let secondBend1 = firstScaledCorner + dropRelativeToBendPoint
                 let secondBend2 = secondScaledCorner + dropRelativeToBendPoint
                 let secondOuterBendExtension1 = firstFullCorner
                 let secondInnerBendExtension1 = firstScaledCorner + dropRelativeToBendPoint
                 let secondOuterBendExtension2 = secondFullCorner
                 let secondInnerBendExtension2 = secondScaledCorner + dropRelativeToBendPoint
                 let bottomCorner1 = bottomEdge.vertex0
                 let bottomCorner2 = bottomEdge.vertex1

                 let bendAllowanceVector = edge.normal.scaled(by: bendArcLength)

                 let top1Backrotated = top1.rotated(by: bendRotation, pivot: pivotPoint) + bendAllowanceVector
                 let top2Backrotated = top2.rotated(by: bendRotation, pivot: pivotPoint) + bendAllowanceVector
                 let secondBend1Backrotated = secondBend1.rotated(by: bendRotation, pivot: pivotPoint) + bendAllowanceVector
                 let secondBend2Backrotated = secondBend2.rotated(by: bendRotation, pivot: pivotPoint) + bendAllowanceVector
                 let secondOuterBendExtension1Backrotated = secondOuterBendExtension1.rotated(by: bendRotation, pivot: pivotPoint) + bendAllowanceVector
                 let secondInnerBendExtension1Backrotated = secondInnerBendExtension1.rotated(by: bendRotation, pivot: pivotPoint) + bendAllowanceVector
                 let secondOuterBendExtension2Backrotated = secondOuterBendExtension2.rotated(by: bendRotation, pivot: pivotPoint) + bendAllowanceVector
                 let secondInnerBendExtension2Backrotated = secondInnerBendExtension2.rotated(by: bendRotation, pivot: pivotPoint) + bendAllowanceVector
                 let bottomCorner1Backrotated = bottomCorner1.rotated(by: bendRotation, pivot: pivotPoint) + bendAllowanceVector
                 let bottomCorner2Backrotated = bottomCorner2.rotated(by: bendRotation, pivot: pivotPoint) + bendAllowanceVector

                 LineSection(from: scaledEdge.vertex0, to: top1Backrotated)
                 LineSection(from: scaledEdge.vertex1, to: top2Backrotated)

                 Decoration(lineStyle: .bendDash) {
                     LineSection(from: scaledEdge.vertex0, to: scaledEdge.vertex1)
                 }

                 Decoration(lineStyle: .bendDash) {
                     LineSection(from: top1Backrotated, to: top2Backrotated)
                 }

                 Decoration(lineStyle: .bendDash) {
                     LineSection(from: secondBend1Backrotated, to: secondBend2Backrotated)
                 }

                 LineSection(from: secondOuterBendExtension1Backrotated, to: secondInnerBendExtension1Backrotated)
                 LineSection(from: secondInnerBendExtension2Backrotated, to: secondOuterBendExtension2Backrotated)

                 LineSection(from: secondOuterBendExtension1Backrotated, to: bottomCorner1Backrotated)
                 LineSection(from: secondOuterBendExtension2Backrotated, to: bottomCorner2Backrotated)
                 LineSection(from: bottomCorner1Backrotated, to: bottomCorner2Backrotated)
             }
              */

            /*
             // built inside out
             Decoration(color: .purple) {
                 let firstCorner = bendPoint + edge.edge.scaled(by: -0.5)
                 let firstPivotPoint = firstCorner + pivotPointRelativeToBendPoint
                 let toFirstLegTop = dropRelativeToBendPoint - pivotPointRelativeToBendPoint
                 let toFirstLegBottom = toFirstLegTop + bottomEdge.vertex0 - firstFullCorner
                 let toFirstLegTopRotated = bendRotation.act(toFirstLegTop)
                 let toFirstLegBottomRotated = bendRotation.act(toFirstLegBottom)

                 let firstEdgeExtension = (firstScaledCorner - firstFullCorner + dropRelativeToBendPoint).length
                 let secondEdgeExtension = (secondScaledCorner - secondFullCorner + dropRelativeToBendPoint).length

                 let secondCorner = bendPoint + edge.edge.scaled(by: 0.5)
                 let secondPivotPoint = secondCorner + pivotPointRelativeToBendPoint
                 let toSecondLegTop = dropRelativeToBendPoint - pivotPointRelativeToBendPoint
                 let toSecondLegBottom = toSecondLegTop + bottomEdge.vertex1 - secondFullCorner
                 let toSecondLegTopRotated = bendRotation.act(toSecondLegTop)
                 let toSecondLegBottomRotated = bendRotation.act(toSecondLegBottom)

                 let bendAllowance = bendAngle * state.bendRadius

                 let bendAllowenceOffset = edge.normal.scaled(by: bendAllowance)

                 let firstEdgeExtensionPoint = bendAllowenceOffset + firstPivotPoint + toFirstLegTopRotated + edge.direction.scaled(by: firstEdgeExtension)
                 let secondEdgeExtensionPoint = bendAllowenceOffset + secondPivotPoint + toSecondLegTopRotated + edge.direction.scaled(by: -secondEdgeExtension)

                 LineSection(from: bendAllowenceOffset + firstPivotPoint + toFirstLegTopRotated,
                             to: bendAllowenceOffset + firstPivotPoint + toFirstLegBottomRotated)

                 LineSection(from: bendAllowenceOffset + firstPivotPoint + toFirstLegTopRotated,
                             to: firstEdgeExtensionPoint)

                 LineSection(from: bendAllowenceOffset + secondPivotPoint + toSecondLegTopRotated,
                             to: bendAllowenceOffset + secondPivotPoint + toSecondLegBottomRotated)

                 LineSection(from: bendAllowenceOffset + firstPivotPoint + toFirstLegBottomRotated,
                             to: bendAllowenceOffset + secondPivotPoint + toSecondLegBottomRotated)

                 LineSection(from: bendAllowenceOffset + secondPivotPoint + toSecondLegTopRotated,
                             to: secondEdgeExtensionPoint)

                 Decoration(lineStyle: .bendDash) {
                     LineSection(from: firstEdgeExtensionPoint,
                                 to: secondEdgeExtensionPoint)

                     LineSection(from: firstScaledCorner,
                                 to: secondScaledCorner)
                 }

                 LineSection(from: firstEdgeExtensionPoint,
                             to: firstScaledCorner)
                 LineSection(from: secondEdgeExtensionPoint,
                             to: secondScaledCorner)
             }
             */

            /*

             // 2d handmade aligned with top
             Decoration(color: .red) {
                 let bendExtension = backRotatedEdge.normal.scaled(by: bendArcLength)
                 LineSection(from: backRotatedEdge.vertex0, to: backRotatedEdge.vertex0 + bendExtension)
                 LineSection(from: backRotatedEdge.vertex1, to: backRotatedEdge.vertex1 + bendExtension)

                 let firstEdgeExtension = (firstScaledCorner - firstFullCorner + dropRelativeToBendPoint).length
                 let secondEdgeExtension = (secondScaledCorner - secondFullCorner + dropRelativeToBendPoint).length

                 let firstLegLength = ((firstFullCorner + dropRelativeToBendPoint) - bottomEdge.vertex0).length
                 let secondLegLength = ((secondFullCorner + dropRelativeToBendPoint) - bottomEdge.vertex1).length

                 let firstFullFlatCorner = backRotatedEdge.vertex0 + bendExtension + backRotatedEdge.direction.scaled(by: -firstEdgeExtension)

                 let secondFullFlatCorner = backRotatedEdge.vertex1 + bendExtension + backRotatedEdge.direction.scaled(by: secondEdgeExtension)

                 let legRotation = Quat(angle: oppositeRotationAngle, axis: Vector(0, 0, 1))
                 let firstLeg = legRotation.act(backRotatedEdge.normal.scaled(by: firstLegLength))
                 let secondLeg = legRotation.act(backRotatedEdge.normal.scaled(by: secondLegLength))

                 Decoration(lineStyle: .bendDash) {
                     LineSection(from: backRotatedEdge.vertex0, to: backRotatedEdge.vertex1)
                 }

                 Decoration(lineStyle: .bendDash) {
                     LineSection(from: backRotatedEdge.vertex0 + bendExtension,
                                 to: backRotatedEdge.vertex1 + bendExtension)
                 }

                 LineSection(from: backRotatedEdge.vertex0 + bendExtension,
                             to: firstFullFlatCorner)

                 LineSection(from: backRotatedEdge.vertex1 + bendExtension,
                             to: secondFullFlatCorner)

                 LineSection(from: firstFullFlatCorner,
                             to: firstFullFlatCorner + firstLeg)

                 LineSection(from: secondFullFlatCorner,
                             to: secondFullFlatCorner + secondLeg)

                 LineSection(from: firstFullFlatCorner + firstLeg,
                             to: secondFullFlatCorner + secondLeg)
             }
              */
        }
    }
}
