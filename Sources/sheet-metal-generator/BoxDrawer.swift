/*
import AppKit
import Cocoa
import Foundation
import simd
import SwiftUI
import CanvasRender

struct BoxDrawer {
    let context: CGContext
    let state: ObservableState
    let frame: CGRect

    func draw() {
        let plane = plane(of: state.size, aroundX: state.angleAreoundX, andY: state.angleAreoundY)

        // bounding box
        let mid = CGPoint(x: frame.width / 2, y: frame.height / 2)
        context.setStrokeColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.setLineDash(phase: 2, lengths: [5, 5])
        context.beginPath()
        context.move(to: plane.upperLeft.xy.cgPoint * state.scale + mid)
        context.addLine(to: plane.upperRight.xy.cgPoint * state.scale + mid)
        context.addLine(to: plane.lowerRight.xy.cgPoint * state.scale + mid)
        context.addLine(to: plane.lowerLeft.xy.cgPoint * state.scale + mid)
        context.addLine(to: plane.upperLeft.xy.cgPoint * state.scale + mid)
        context.strokePath()
        context.setLineDash(phase: 0, lengths: [])

        // side flap
        let upBendDeduction = self.bendDeduction(angle: 90 + state.angleAreoundX,
                                                 insideRadius: state.bendRadius,
                                                 kFactor: state.kFactor,
                                                 materialThickness: state.thickness)

        let upBendAllowance = self.bendAllowance(angle: 90 + state.angleAreoundX,
                                                 insideRadius: state.bendRadius,
                                                 kFactor: state.kFactor,
                                                 materialThickness: state.thickness)

        let leftBendDeduction = self.bendDeduction(angle: 90 + state.angleAreoundY,
                                                   insideRadius: state.bendRadius,
                                                   kFactor: state.kFactor,
                                                   materialThickness: state.thickness)

        let leftBendAllowance = self.bendAllowance(angle: 90 + state.angleAreoundY,
                                                   insideRadius: state.bendRadius,
                                                   kFactor: state.kFactor,
                                                   materialThickness: state.thickness)

        let rightBendDeduction = self.bendDeduction(angle: 90 - state.angleAreoundY,
                                                    insideRadius: state.bendRadius,
                                                    kFactor: state.kFactor,
                                                    materialThickness: state.thickness)

        let rightBendAllowance = self.bendAllowance(angle: 90 - state.angleAreoundY,
                                                    insideRadius: state.bendRadius,
                                                    kFactor: state.kFactor,
                                                    materialThickness: state.thickness)

        let downBendDeduction = self.bendDeduction(angle: 90 - state.angleAreoundX,
                                                   insideRadius: state.bendRadius,
                                                   kFactor: state.kFactor,
                                                   materialThickness: state.thickness)

        let downBendAllowance = self.bendAllowance(angle: 90 - state.angleAreoundX,
                                                   insideRadius: state.bendRadius,
                                                   kFactor: state.kFactor,
                                                   materialThickness: state.thickness)

        let upSide = (plane.upperRight - plane.upperLeft)
        let upSideNormal = upSide.xyPerp

        let rightSide = (plane.lowerRight - plane.upperRight)
        let rightSideNormal = rightSide.xyPerp

        let downSide = (plane.lowerLeft - plane.lowerRight)
        let downSideNormal = downSide.xyPerp

        let leftSide = (plane.upperLeft - plane.lowerLeft)
        let leftSideNormal = leftSide.xyPerp

        let leftAlongUp = leftSideNormal.scaled(by: -leftBendDeduction).projected(onto: upSide)
        let rightAlongUp = rightSideNormal.scaled(by: -rightBendDeduction).projected(onto: upSide)

        let upAlongRight = upSideNormal.projected(onto: rightSide)
        let downAlongRight = downSideNormal.projected(onto: rightSide)

        draw(vector: leftAlongUp * state.scale, at: mid, onto: context)

        context.setStrokeColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))

        // up
        context.beginPath()
        context.move(to: (plane.upperLeft + upSideNormal.scaled(by: -upBendDeduction) + leftAlongUp).xy.cgPoint * state.scale + mid)
        context.addLine(to: (plane.upperLeft + upSideNormal.scaled(by: -upBendDeduction) + leftAlongUp + upSideNormal.scaled(by: upBendAllowance)).xy.cgPoint * state.scale + mid)
        context.addLine(to: (plane.upperRight + upSideNormal.scaled(by: -upBendDeduction) + rightAlongUp + upSideNormal.scaled(by: upBendAllowance)).xy.cgPoint * state.scale + mid)
        context.addLine(to: (plane.upperRight + upSideNormal.scaled(by: -upBendDeduction) + rightAlongUp).xy.cgPoint * state.scale + mid)
        context.strokePath()

        // right
        context.beginPath()
        context.move(to: (plane.upperRight + rightSideNormal.scaled(by: -rightBendDeduction) + upAlongRight.scaled(by: -upBendDeduction)).xy.cgPoint * state.scale + mid)
        context.addLine(to: (plane.upperRight + rightSideNormal.scaled(by: -rightBendDeduction) + upAlongRight.scaled(by: -upBendDeduction) + rightSideNormal.scaled(by: rightBendAllowance)).xy.cgPoint * state.scale + mid)
        context.addLine(to: (plane.lowerRight + rightSideNormal.scaled(by: -rightBendDeduction) + downAlongRight.scaled(by: -downBendDeduction) + rightSideNormal.scaled(by: rightBendAllowance)).xy.cgPoint * state.scale + mid)
        context.addLine(to: (plane.lowerRight + rightSideNormal.scaled(by: -rightBendDeduction) + downAlongRight.scaled(by: -downBendDeduction)).xy.cgPoint * state.scale + mid)
        context.strokePath()

        drawBend(plane: plane, at: mid + CGPoint(x: 200, y: 0), onto: context)
    }

    private func drawBend(plane: Plane, at origo: CGPoint, onto context: CGContext) {
        context.setStrokeColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.setLineDash(phase: 2, lengths: [5, 5])
        context.beginPath()

        let radians = state.angleAreoundY * (.pi / 180)
        let topLeg = Vector(x: state.size, y: state.size, z: 0).rotated(by: Quat(angle: radians, axis: [0, -1, 0]))
        let otherLeg = Vector(x: 0, y: 0, z: state.size)

        // drawing the right side in the xz-plane
        context.move(to: origo)
        context.addLine(to: origo + topLeg.scaled(by: state.scale).xz.cgPoint)
        context.addLine(to: origo + (topLeg + otherLeg).scaled(by: state.scale).xz.cgPoint)

        context.strokePath()
        context.setLineDash(phase: 0, lengths: [])
    }

    private func draw(vector: simd_double3, at origo: CGPoint, onto context: CGContext) {
        let arrowLeftSide = vector.normalized.scaled(by: 5).rotated(by: Quat(angle: 170.degreesToRadians, axis: Vector(0, 0, 1)))
        let arrowRightSide = vector.normalized.scaled(by: 5).rotated(by: Quat(angle: -170.degreesToRadians, axis: Vector(0, 0, 1)))

        context.beginPath()
        context.move(to: origo)
        context.addLine(to: vector.xy.cgPoint + origo)
        context.addLine(to: (vector + arrowRightSide).xy.cgPoint + origo)
        context.move(to: vector.xy.cgPoint + origo)
        context.addLine(to: (vector + arrowLeftSide).xy.cgPoint + origo)
        context.strokePath()
    }

    /// Construct a plane where the square corners is projected onto a tilted plane that is then rotated back into the origin plane
    func plane(of size: Double,
               aroundX angleAroundX: Double,
               andY angleAroundY: Double) -> Plane {
        let xRads = angleAroundX * .pi / 180
        let yRads = angleAroundY * .pi / 180
        let xRotation = Quat(angle: xRads, axis: Vector(x: 1, y: 0, z: 0))
        let yRotation = Quat(angle: yRads, axis: Vector(x: 0, y: 1, z: 0))
        let rotation = yRotation * xRotation

        let upperLeft = Vector(x: -size / 2, y: -size / 2, z: 0)
        let upperRight = Vector(x: size / 2, y: -size / 2, z: 0)
        let lowerRight = Vector(x: size / 2, y: size / 2, z: 0)
        let lowerLeft = Vector(x: -size / 2, y: size / 2, z: 0)

        let up = Vector(x: 0, y: 0, z: 1)

        let planeNormal = rotation.act(Vector(x: 0, y: 0, z: -1))
        let planeOrigin = Vector(x: 0, y: 0, z: size)

        guard let upperLeftHit = up.intersectPlane(normal: planeNormal, planeOrigin: planeOrigin, rayOrigin: upperLeft) else {
            fatalError("upperLeftHit does not have a hit point on the plane")
        }
        guard let upperRightHit = up.intersectPlane(normal: planeNormal, planeOrigin: planeOrigin, rayOrigin: upperRight) else {
            fatalError("upperRightHit does not have a hit point on the plane")
        }
        guard let lowerRightHit = up.intersectPlane(normal: planeNormal, planeOrigin: planeOrigin, rayOrigin: lowerRight) else {
            fatalError("lowerRightHit does not have a hit point on the plane")
        }
        guard let lowerLeftHit = up.intersectPlane(normal: planeNormal, planeOrigin: planeOrigin, rayOrigin: lowerLeft) else {
            fatalError("lowerLeftHit does not have a hit point on the plane")
        }

        let upperLeftResult = rotation.inverse.act(upperLeftHit - planeOrigin)
        let upperRightResult = rotation.inverse.act(upperRightHit - planeOrigin)
        let lowerRightResult = rotation.inverse.act(lowerRightHit - planeOrigin)
        let lowerLeftResult = rotation.inverse.act(lowerLeftHit - planeOrigin)

        return Plane(upperLeft: upperLeftResult,
                     upperRight: upperRightResult,
                     lowerRight: lowerRightResult,
                     lowerLeft: lowerLeftResult)
    }

    /// Bend allowance is defined as the material required to add to the overall length of the sheet metal in order for it to get cut in the right size.
    func bendAllowance(angle: Double, insideRadius: Double, kFactor: Double, materialThickness: Double) -> Double {
        return angle * (.pi / 180.0) * (insideRadius + kFactor * materialThickness)
    }

    /// The Bend Deduction BD is defined as the difference between the sum of the flange lengths (from edge to the apex) and the initial flat length.  In other words, the material you will have to remove from the total length of the flanges in order to arrive at the proper length in the flat pattern.
    func bendDeduction(angle: Double, insideRadius: Double, kFactor: Double, materialThickness: Double) -> Double {
        let ba = bendAllowance(angle: angle, insideRadius: insideRadius, kFactor: kFactor, materialThickness: materialThickness)
        let ossb = outsideSetback(angle: angle, insideRadius: insideRadius, materialThickness: materialThickness)
        return 2.0 * ossb - ba
    }

    // The outside setback is a dimensional value that begins at the tangent of the radius and the flat of the leg, measuring to the apex of the bend.
    func outsideSetback(angle: Double, insideRadius: Double, materialThickness: Double) -> Double {
        return tan((angle * (.pi / 180.0)) / 2.0) * (insideRadius + materialThickness)
    }

    func flatBlankLength(firstDistanceToApex: Double, secondDistanceToApex: Double, bendAllowance: Double) -> Double {
        return firstDistanceToApex + secondDistanceToApex + bendAllowance
    }

    func flatBlankLength(firstDistanceToApex: Double, secondDistanceToApex: Double, bendDeduction: Double) -> Double {
        return firstDistanceToApex + secondDistanceToApex - bendDeduction
    }

    func distanceToApex(legLength: Double, angle: Double, insideRadius: Double, materialThickness: Double) -> Double {
        return legLength + outsideSetback(angle: angle, insideRadius: insideRadius, materialThickness: materialThickness)
    }

    func neutralAxisRadius(insideRadius: Double, materialThickness: Double, kFactor: Double) -> Double {
        return insideRadius + materialThickness * kFactor
    }
}
*/
