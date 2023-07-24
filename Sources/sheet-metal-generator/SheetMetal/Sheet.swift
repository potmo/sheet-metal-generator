import CanvasRender
import CoreGraphics
import Foundation

struct Sheet {
    ///     N
    ///  v0 ---- v1
    /// W |            | E
    ///  v3 ---- v2
    ///     S
    let top: Plane
    let bottom: Plane
    let thickness: Double
    let northSide: SheetEdge
    let eastSide: SheetEdge
    let southSide: SheetEdge
    let westSide: SheetEdge

    var normal: Vector {
        return top.normal
    }

    init(extrudendFrom bottomPlane: Plane, thickness: Double) {
        self.bottom = bottomPlane

        let thicknessVector = bottomPlane.normal * thickness
        self.top = Plane(vertex0: bottom.vertex0 + thicknessVector,
                         vertex1: bottom.vertex1 + thicknessVector,
                         vertex2: bottom.vertex2 + thicknessVector,
                         vertex3: bottom.vertex3 + thicknessVector)

        self.thickness = thickness

        self.northSide = .solid
        self.eastSide = .solid
        self.southSide = .solid
        self.westSide = .solid
    }

    init(top: Plane,
         bottom: Plane,
         thickness: Double,
         northSide: SheetEdge,
         eastSide: SheetEdge,
         southSide: SheetEdge,
         westSide: SheetEdge) {
        self.top = top
        self.bottom = bottom
        self.thickness = thickness
        self.northSide = northSide
        self.eastSide = eastSide
        self.southSide = southSide
        self.westSide = westSide
    }

    func extrudedEast(_ amount: Double) -> Sheet {
        let extrusionVector = eastFace.faceNormal.scaled(by: amount)
        let newBottom = Plane(vertex0: bottom.vertex0,
                              vertex1: bottom.vertex1 + extrusionVector,
                              vertex2: bottom.vertex2 + extrusionVector,
                              vertex3: bottom.vertex3)
        return Sheet(extrudendFrom: newBottom, thickness: thickness)
    }

    func extrudedWest(_ amount: Double) -> Sheet {
        let extrusionVector = westFace.faceNormal.scaled(by: amount)
        let newBottom = Plane(vertex0: bottom.vertex0 + extrusionVector,
                              vertex1: bottom.vertex1,
                              vertex2: bottom.vertex2,
                              vertex3: bottom.vertex3 + extrusionVector)
        return Sheet(extrudendFrom: newBottom, thickness: thickness)
    }

    func extrudedNorth(_ amount: Double) -> Sheet {
        let extrusionVector = northFace.faceNormal.scaled(by: amount)
        let newBottom = Plane(vertex0: bottom.vertex0 + extrusionVector,
                              vertex1: bottom.vertex1 + extrusionVector,
                              vertex2: bottom.vertex2,
                              vertex3: bottom.vertex3)
        return Sheet(extrudendFrom: newBottom, thickness: thickness)
    }

    func extrudedSouth(_ amount: Double) -> Sheet {
        let extrusionVector = southFace.faceNormal.scaled(by: amount)
        let newBottom = Plane(vertex0: bottom.vertex0,
                              vertex1: bottom.vertex1,
                              vertex2: bottom.vertex2 + extrusionVector,
                              vertex3: bottom.vertex3 + extrusionVector)
        return Sheet(extrudendFrom: newBottom, thickness: thickness)
    }

    func withBendNorth(_ bend: Bend) -> Sheet {
        return Sheet(top: top,
                     bottom: bottom,
                     thickness: thickness,
                     northSide: .bend(bend),
                     eastSide: eastSide,
                     southSide: southSide,
                     westSide: westSide)
    }

    func withBendEast(_ bend: Bend) -> Sheet {
        return Sheet(top: top,
                     bottom: bottom,
                     thickness: thickness,
                     northSide: northSide,
                     eastSide: .bend(bend),
                     southSide: southSide,
                     westSide: westSide)
    }

    func withBendSouth(_ bend: Bend) -> Sheet {
        return Sheet(top: top,
                     bottom: bottom,
                     thickness: thickness,
                     northSide: northSide,
                     eastSide: eastSide,
                     southSide: .bend(bend),
                     westSide: westSide)
    }

    func withBendWest(_ bend: Bend) -> Sheet {
        return Sheet(top: top,
                     bottom: bottom,
                     thickness: thickness,
                     northSide: northSide,
                     eastSide: eastSide,
                     southSide: southSide,
                     westSide: .bend(bend))
    }

    var eastFace: SheetEdgeFace {
        let edge = SheetEdgeFace(topVertex0: top.vertex2,
                                 topVertex1: top.vertex1,
                                 bottomVertex0: bottom.vertex2,
                                 bottomVertex1: bottom.vertex1,
                                 setFaceNormal: (bottom.vertex1 - bottom.vertex0).normalized)

        return edge
    }

    var westFace: SheetEdgeFace {
        return SheetEdgeFace(topVertex0: top.vertex0,
                             topVertex1: top.vertex3,
                             bottomVertex0: bottom.vertex0,
                             bottomVertex1: bottom.vertex3,
                             setFaceNormal: (bottom.vertex0 - bottom.vertex1).normalized)
    }

    var northFace: SheetEdgeFace {
        return SheetEdgeFace(topVertex0: top.vertex1,
                             topVertex1: top.vertex0,
                             bottomVertex0: bottom.vertex1,
                             bottomVertex1: bottom.vertex0,
                             setFaceNormal: (bottom.vertex0 - bottom.vertex3).normalized)
    }

    var southFace: SheetEdgeFace {
        return SheetEdgeFace(topVertex0: top.vertex3,
                             topVertex1: top.vertex2,
                             bottomVertex0: bottom.vertex3,
                             bottomVertex1: bottom.vertex2,
                             setFaceNormal: (bottom.vertex3 - bottom.vertex0).normalized)
    }
}

struct SheetEdgeFace {
    let topVertex0: Vector
    let topVertex1: Vector
    let bottomVertex0: Vector
    let bottomVertex1: Vector

    let setFaceNormal: Vector

    var thickness: Double {
        return (topVertex0 - bottomVertex0).length
    }

    var sheetNormal: Vector {
        return (topVertex0 - bottomVertex0).normalized
    }

    var topEdgeDirection: Vector {
        return (topVertex1 - topVertex0).normalized
    }

    var sideEdgeDirection: Vector {
        return (bottomVertex0 - topVertex0).normalized
    }

    var faceNormal: Vector {
        return setFaceNormal
    }

    var computedFaceNormal: Vector {
        return Vector.normalFromClockwiseVertices(a: topVertex0, b: topVertex1, c: bottomVertex1)
    }

    var vertices: [Vector] {
        return [topVertex0, topVertex1, bottomVertex1, bottomVertex0]
    }
}

indirect enum SheetEdge {
    case solid
    case bend(_ bend: Bend)
    case extrusion(_ sheet: Sheet)
}

struct OrtographicSheet: DrawableObject {
    let sheet: Sheet
    let renderPlane: AxisPlane

    @CanvasBuilder var shapes: [DrawableShape] {
        let bottom = sheet.bottom.vertices.map { $0.inPlane(renderPlane) }
        let top = sheet.top.vertices.map { $0.inPlane(renderPlane) }

        let sides = [
            (sheet.northSide, sheet.northFace),
            (sheet.eastSide, sheet.eastFace),
            (sheet.southSide, sheet.southFace),
            (sheet.westSide, sheet.westFace),
        ]

        for (side, face) in sides {
            switch side {
            case .solid:
                LineSection(from: face.topVertex0, to: face.topVertex1, plane: renderPlane)
                LineSection(from: face.bottomVertex0, to: face.bottomVertex1, plane: renderPlane)
            case let .bend(bend):
                Decoration(lineStyle: .dashed(lengths: [2, 5, 2])) {
                    Decoration(color: .blue) {
                        LineSection(from: face.topVertex0, to: face.topVertex1, plane: renderPlane)
                    }

                    Decoration(color: .green) {
                        LineSection(from: face.bottomVertex0, to: face.bottomVertex1, plane: renderPlane)
                    }
                }
                OrtographicBend(bend: bend, renderPlane: renderPlane)
            case let .extrusion(sheet):
                OrtographicSheet(sheet: sheet, renderPlane: renderPlane)
            }
        }

        let topCenter = sheet.top.vertices.reduce(Vector(), +).scaled(by: 1.0 / 4.0)
        Decoration(color: .pink, lineStyle: .dashed()) {
            LineSection(from: topCenter, to: topCenter + sheet.normal.scaled(by: 5.0), plane: renderPlane)
        }

        // corners
        for (bottomPoint, topPoint) in zip(bottom, top) {
            LineSection(from: bottomPoint, to: topPoint)
        }
    }
}
