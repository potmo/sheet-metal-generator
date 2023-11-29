import AppKit
import CanvasRender
import Cocoa
import Combine
import Foundation
import simd
import SwiftUI

struct SideView: ShapeMaker {
    typealias StateType = InputState

    let renderPlane: AxisPlane

    @CanvasBuilder
    func shapes(from state: InputState) -> [DrawableShape] {
        let state = state.frozen

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
        Decoration(color: .orange, lineStyle: .dashed()) {
            let outline = [
                Vector(-state.size / 2, -state.size / 2, 0),
                Vector(state.size / 2, -state.size / 2, 0),
                Vector(state.size / 2, state.size / 2, 0),
                Vector(-state.size / 2, state.size / 2, 0),
            ]
            Polygon(vertices: outline)
        }

        let northBendAngle = (90 + state.angleAroundX).degreesToRadians
        let eastBendAngle = (90 - state.angleAroundY).degreesToRadians
        let southBendAngle = (90 - state.angleAroundX).degreesToRadians
        let westBendAngle = (90 + state.angleAroundY).degreesToRadians

        // offset in to make space for sheet thickness
        let plane = Plane(fitting: state.size - state.thickness * 2,
                          rotatedAroundX: state.angleAroundX,
                          andY: state.angleAroundY)
        // .offsetted(by: [0, 0, -state.thickness]) // bring top face down to zero
        //   .offsetted(by: [0, 0, state.height]) // bring height up so it stands on zero

        let preSheet = Sheet(extrudendFrom: plane, thickness: state.thickness)
        /*
                Decoration(color: .orange) {
                    let testSheet = preSheet
                    LineSection(from: testSheet.northFace.bottomVertex0, to: testSheet.northFace.bottomVertex1, plane: renderPlane)
                    LineSection(from: testSheet.eastFace.bottomVertex0, to: testSheet.eastFace.bottomVertex1, plane: renderPlane)
                    LineSection(from: testSheet.southFace.bottomVertex0, to: testSheet.southFace.bottomVertex1, plane: renderPlane)
                    LineSection(from: testSheet.westFace.bottomVertex0, to: testSheet.westFace.bottomVertex1, plane: renderPlane)

                    let northMid = testSheet.northFace.bottomVertex0 + (testSheet.northFace.bottomVertex1 - testSheet.northFace.bottomVertex0).scaled(by: 0.5)
                    LineSection(from: northMid,
                                to: northMid + testSheet.northFace.faceNormal.scaled(by: 5), plane: renderPlane)

                    Circle(center: northMid, radius: 3, plane: renderPlane)
                }

                Decoration(color: .teal) {
                    LineSection(from: preSheet.northFace.topVertex0, to: preSheet.northFace.topVertex1, plane: renderPlane)
                    LineSection(from: preSheet.eastFace.topVertex0, to: preSheet.eastFace.topVertex1, plane: renderPlane)
                    LineSection(from: preSheet.southFace.topVertex0, to: preSheet.southFace.topVertex1, plane: renderPlane)
                    LineSection(from: preSheet.westFace.topVertex0, to: preSheet.westFace.topVertex1, plane: renderPlane)

                    let northMid = preSheet.northFace.topVertex0 + (preSheet.northFace.topVertex1 - preSheet.northFace.topVertex0).scaled(by: 0.5)
                    LineSection(from: northMid,
                                to: northMid + preSheet.northFace.faceNormal.scaled(by: 5), plane: renderPlane)

                    Circle(center: northMid, radius: 3, plane: renderPlane)
                }
         */

        let sheet = preSheet
            .extrudedEast(-Bend.insideSetback(angle: eastBendAngle,
                                              radius: state.bendRadius))
            .extrudedWest(-Bend.insideSetback(angle: westBendAngle,
                                              radius: state.bendRadius))
            .extrudedNorth(-Bend.insideSetback(angle: northBendAngle,
                                               radius: state.bendRadius))
            .extrudedSouth(-Bend.insideSetback(angle: southBendAngle,
                                               radius: state.bendRadius))
        /*
         Decoration(color: .pink) {
             let testSheet = sheet
             LineSection(from: testSheet.northFace.bottomVertex0, to: testSheet.northFace.bottomVertex1, plane: renderPlane)
             LineSection(from: testSheet.eastFace.bottomVertex0, to: testSheet.eastFace.bottomVertex1, plane: renderPlane)
             LineSection(from: testSheet.southFace.bottomVertex0, to: testSheet.southFace.bottomVertex1, plane: renderPlane)
             LineSection(from: testSheet.westFace.bottomVertex0, to: testSheet.westFace.bottomVertex1, plane: renderPlane)

             let northMid = testSheet.northFace.bottomVertex0 + (testSheet.northFace.bottomVertex1 - testSheet.northFace.bottomVertex0).scaled(by: 0.5)
             LineSection(from: northMid,
                         to: northMid + testSheet.northFace.faceNormal.scaled(by: 5), plane: renderPlane)

             Circle(center: northMid, radius: 3, plane: renderPlane)
         }
         */

        let eastBend = Bend(from: sheet.eastFace,
                            angle: eastBendAngle,
                            radius: state.bendRadius,
                            kFactor: state.kFactor)

        let westBend = Bend(from: sheet.westFace,
                            angle: westBendAngle,
                            radius: state.bendRadius,
                            kFactor: state.kFactor)

        let northBend = Bend(from: sheet.northFace,
                             angle: northBendAngle,
                             radius: state.bendRadius,
                             kFactor: state.kFactor)

        let southBend = Bend(from: sheet.southFace,
                             angle: southBendAngle,
                             radius: state.bendRadius,
                             kFactor: state.kFactor)

        let bentSheet = sheet
            .withBendNorth(northBend)
            .withBendEast(eastBend)
            .withBendSouth(southBend)
            .withBendWest(westBend)

        OrtographicSheet(sheet: bentSheet)
    }
}
