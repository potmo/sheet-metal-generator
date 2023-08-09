import AppKit
import CanvasRender
import Cocoa
import Combine
import Foundation
import simd
import SwiftUI

struct BendDisplay: ShapeMaker {
    typealias StateType = InputState

    @CanvasBuilder
    func shapes(from state: InputState) -> [DrawableShape] {
        let start = Vector(0, 0, 0)

        let topVector = Vector(x: state.size, y: 0, z: 0).rotated(by: state.angleAroundY.degreesToRadians, around: .z)
        let thicknessVector = topVector.xyPerp.normalized.scaled(by: state.thickness)

        let downVector = topVector.rotated(by: (90 - state.angleAroundY).degreesToRadians, around: .z)
        let downThicknessVector = downVector.xyPerp.normalized.scaled(by: state.thickness)

        let centerOfRotation = topVector + -topVector.xyPerp.normalized * state.bendRadius

        LineSection(from: start + thicknessVector,
                    to: start + thicknessVector + topVector)

        LineSection(from: start, to: topVector)

        Arc(center: centerOfRotation,
            radius: state.bendRadius,
            startAngle: (state.angleAroundY - 90).degreesToRadians,
            endAngle: 0)

        Arc(center: centerOfRotation,
            radius: state.bendRadius + state.thickness,
            startAngle: (state.angleAroundY - 90).degreesToRadians,
            endAngle: 0)

        let neutralAxisRadius = state.bendRadius + state.thickness * state.kFactor

        Decoration(color: .green, lineStyle: .dashed()) {
            Arc(center: centerOfRotation,
                radius: neutralAxisRadius,
                startAngle: (state.angleAroundY - 90).degreesToRadians,
                endAngle: 0)
        }

        let firstBendLine = start + topVector
        let secondBendLine = firstBendLine.rotated(by: (90 - state.angleAroundY).degreesToRadians, around: .z, pivot: centerOfRotation)

        Decoration(color: .black.opacity(0.5), lineStyle: .dashed(phase: 2, lengths: [2, 2])) {
            LineSection(from: firstBendLine, to: firstBendLine + thicknessVector)
            LineSection(from: secondBendLine, to: secondBendLine + downThicknessVector)
        }

        Point(firstBendLine)
        Point(secondBendLine)
        Point(centerOfRotation)

        Decoration(color: .gray, lineStyle: .dashed(phase: 2, lengths: [2, 2])) {
            LineSection(from: centerOfRotation, to: firstBendLine)
            LineSection(from: centerOfRotation, to: secondBendLine)
        }

        let setBack = outsideSetback(angle: (90 - state.angleAroundY).degreesToRadians,
                                     insideRadius: state.bendRadius,
                                     materialThickness: state.thickness)

        let setBackVector = topVector.normalized.scaled(by: setBack)

        let setBackDownVector = topVector.normalized.scaled(by: setBack).rotated(by: (90 - state.angleAroundY).degreesToRadians,
                                                                                 around: .z)

        let apex = start + topVector + thicknessVector + setBackVector
        Decoration(color: .blue) {
            Point(apex)
        }

        Decoration(color: .red, lineStyle: .dashed(phase: 2, lengths: [2, 2])) {
            LineSection(from: start + topVector + thicknessVector,
                        to: start + topVector + thicknessVector + setBackVector)

            LineSection(from: start + topVector + thicknessVector + setBackVector,
                        to: start + topVector + thicknessVector + setBackVector + setBackDownVector)
        }

        LineSection(from: start + topVector + thicknessVector + setBackVector + setBackDownVector,
                    to: start + topVector + thicknessVector + setBackVector + setBackDownVector + downVector)

        LineSection(from: start + topVector + thicknessVector + setBackVector + setBackDownVector - downThicknessVector,
                    to: start + topVector + thicknessVector + setBackVector + setBackDownVector + downVector - downThicknessVector)
    }

    /// Bend allowance is defined as the material required to add to the overall length of the sheet metal in order for it to get cut in the right size.
    func bendAllowance(angle: Double, insideRadius: Double, kFactor: Double, materialThickness: Double) -> Double {
        return angle * (insideRadius + kFactor * materialThickness)
    }

    /// The Bend Deduction BD is defined as the difference between the sum of the flange lengths (from edge to the apex) and the initial flat length.  In other words, the material you will have to remove from the total length of the flanges in order to arrive at the proper length in the flat pattern.
    func bendDeduction(angle: Double, insideRadius: Double, kFactor: Double, materialThickness: Double) -> Double {
        let ba = bendAllowance(angle: angle, insideRadius: insideRadius, kFactor: kFactor, materialThickness: materialThickness)
        let ossb = outsideSetback(angle: angle, insideRadius: insideRadius, materialThickness: materialThickness)
        return 2.0 * ossb - ba
    }

    // The outside setback is a dimensional value that begins at the tangent of the radius and the flat of the leg, measuring to the apex of the bend.
    func outsideSetback(angle: Double, insideRadius: Double, materialThickness: Double) -> Double {
        return tan(angle / 2.0) * (insideRadius + materialThickness)
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
