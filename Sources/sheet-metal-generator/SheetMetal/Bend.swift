import CanvasRender
import CoreGraphics
import Foundation
import simd

struct Bend {
    let fromFace: SheetEdgeFace
    let angle: Double
    let radius: Double
    let kFactor: Double

    let edge: SheetEdge

    var thickness: Double {
        return fromFace.thickness
    }

    init(from edge: SheetEdgeFace, angle: Double, radius: Double, kFactor: Double) {
        self.fromFace = edge
        self.angle = angle
        self.radius = radius
        self.kFactor = kFactor
        self.edge = .solid
    }

    var outsideSetback: Double {
        Self.outsideSetback(angle: angle, radius: radius, thickness: thickness)
    }

    static func outsideSetback(angle: Double, radius: Double, thickness: Double) -> Double {
        return tan(angle / 2.0) * (radius + thickness)
    }

    // The outside setback is a dimensional value that begins at the tangent of the radius and the flat of the leg, measuring to the apex of the bend.
    static func insideSetback(angle: Double, radius: Double) -> Double {
        return tan(angle / 2.0) * radius
    }

    /// The Bend Deduction BD is defined as the difference between the sum of the flange lengths (from edge to the apex) and the initial flat length.  In other words, the material you will have to remove from the total length of the flanges in order to arrive at the proper length in the flat pattern.
    static func bendDeduction(angle: Double, insideRadius: Double, kFactor: Double, materialThickness: Double) -> Double {
        let ba = bendAllowance(angle: angle, insideRadius: insideRadius, kFactor: kFactor, materialThickness: materialThickness)
        let ossb = outsideSetback(angle: angle, radius: insideRadius, thickness: materialThickness)
        return 2.0 * ossb - ba
    }

    /// Bend allowance is defined as the material required to add to the overall length of the sheet metal in order for it to get cut in the right size.
    /// This is basically the full arc length of the bend at the netrual axis of the kFactor
    static func bendAllowance(angle: Double, insideRadius: Double, kFactor: Double, materialThickness: Double) -> Double {
        return angle * (insideRadius + kFactor * materialThickness)
    }
}

struct OrtographicBend: DrawableObject {
    let bend: Bend
    let renderPlane: AxisPlane

    @CanvasBuilder var shapes: [DrawableShape] {
        let apex = bend.fromFace.topVertex0 + bend.fromFace.faceNormal * bend.outsideSetback

        let rotationPoint = bend.fromFace.bottomVertex0 + bend.fromFace.sheetNormal * -bend.radius
        let rotationAxis = bend.fromFace.topEdgeDirection
        let horizontal = bend.fromFace.faceNormal.with(z: 0).normalized
        let rotation = simd_quatd(from: bend.fromFace.sheetNormal, to: horizontal)

        // let rotationPoint = bend.fromFace.bottomVertex0 + Vector(0, 0, 1) * -bend.radius

        // let rotationAxis = (bend.fromFace.bottomVertex1 - bend.fromFace.bottomVertex0).normalized

        // let rotationPoint = bend.fromFace.bottomVertex0 + -rotationAxis.xyPerp * -bend.radius

        // let rotationAxis = Vector.normalFromClockwiseVertices(a: rotationPoint, b: apex, c: bend.fromFace.bottomVertex0)

        // let rotationAxis = bend.fromFace.sheetNormal.cross(bend.fromFace.faceNormal)

      //  let rotation = Quat(angle: bend.angle, axis: rotationAxis)
        let firstBendPoint = bend.fromFace.bottomVertex0
        let secondBendPoint = rotationPoint + rotation.act(firstBendPoint - rotationPoint)
        let firstOuterBendPoint = bend.fromFace.topVertex0
        let secondOuterBendPoint = rotationPoint + rotation.act(firstOuterBendPoint - rotationPoint)

        let vectorToApex = (apex - rotationPoint).normalized
        let midVectorInSheet = simd_slerp(.identity, rotation, 0.5).act(bend.fromFace.sheetNormal)

        Decoration(color: .blue) {
            Arrow(vector: vectorToApex.scaled(by: 5), origo: rotationPoint, plane: renderPlane)
        }

        Decoration(color: .green) {
            Arrow(vector: midVectorInSheet.scaled(by: 5), origo: rotationPoint, plane: renderPlane)
        }

        Decoration(color: .red) {
            Arrow(vector: bend.fromFace.faceNormal.scaled(by: 5), origo: rotationPoint, plane: renderPlane)
        }

        Decoration(color: .pink) {
            LineSection(from: rotationPoint - rotationAxis.scaled(by: 2.5),
                        to: rotationPoint + rotationAxis.scaled(by: 2.5),
                        plane: renderPlane)
        }

        let faceCenter = bend.fromFace.vertices.reduce(Vector(), +).scaled(by: 1.0 / 4.0)
        Decoration(color: .pink, lineStyle: .dashed()) {
            LineSection(from: faceCenter, to: faceCenter + bend.fromFace.faceNormal.scaled(by: 5.0), plane: renderPlane)
        }

        // radius
        Decoration(color: .gray, lineStyle: .dashed()) {
            LineSection(from: rotationPoint, to: firstBendPoint, plane: renderPlane)
            LineSection(from: rotationPoint, to: secondBendPoint, plane: renderPlane)
        }

        // setback
        Decoration(color: .blue, lineStyle: .dashed()) {
            LineSection(from: bend.fromFace.topVertex0,
                        to: apex,
                        plane: renderPlane)
            LineSection(from: apex,
                        to: secondOuterBendPoint,
                        plane: renderPlane)
        }

        // walls
        Decoration(color: .red) {
            Orbit(pivot: rotationPoint,
                  point: bend.fromFace.bottomVertex0,
                  rotation: rotation,
                  renderPlane: renderPlane)

            Orbit(pivot: rotationPoint,
                  point: bend.fromFace.topVertex0,
                  rotation: rotation,
                  renderPlane: renderPlane)
        }

        // neutral axis
        Decoration(color: .green, lineStyle: .dashed()) {
            Orbit(pivot: rotationPoint,
                  point: bend.fromFace.bottomVertex0 + bend.fromFace.sheetNormal * bend.thickness * bend.kFactor,
                  rotation: rotation,
                  renderPlane: renderPlane)
        }

        switch bend.edge {
        case .solid:
            let sideVector = (bend.fromFace.topVertex1 - bend.fromFace.topVertex0)
            // sides
            LineSection(from: secondBendPoint,
                        to: secondOuterBendPoint,
                        plane: renderPlane)
            LineSection(from: secondBendPoint + sideVector,
                        to: secondOuterBendPoint + sideVector,
                        plane: renderPlane)
            LineSection(from: secondBendPoint,
                        to: secondBendPoint + sideVector,
                        plane: renderPlane)
            LineSection(from: secondOuterBendPoint,
                        to: secondOuterBendPoint + sideVector,
                        plane: renderPlane)
        case .bend(_):
            // FIXME: This is onluy to prevent a warning
            [Circle]()
        case .extrusion(_):
            // FIXME: This is onluy to prevent a warning
            [Circle]()
        }
    }
}
