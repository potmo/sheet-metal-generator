import AppKit
import CanvasRender
import Cocoa
import Combine
import Foundation
import simd
import SwiftUI

public struct BasePlateView: ShapeMaker {
    public typealias StateType = InputState

    let width: Int
    let height: Int
    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    @CanvasBuilder
    public func shapes(from state: StateType) -> [DrawableShape] {
        // LineSection(from: Vector(), to: Vector(100, 0, 0))
        let state = state.frozen

        let insideTabLength = state.insideTabLength

        // base plate

        let xRange = 0 ..< width
        let yRange = 0 ..< (height + 1)

        let baseplateOffset = Vector(0, 80, 0)

        Offset(baseplateOffset) {
            let width = Vector(state.size, 0.0, 0.0).scaled(by: Double(xRange.upperBound) + 0.5)
            let height = Vector(0.0, state.size, 0.0).scaled(by: Double(yRange.upperBound) - 0.25)
            let bottom = Vector(-state.size * 0.75, -state.size * 0.75, 0)
            Polygon(vertices: [
                bottom,
                bottom + width,
                bottom + width + height,
                bottom + height,
            ],
            closed: true)
        }

        // base board holes
        for x in xRange {
            for y in yRange {
                Offset(baseplateOffset + Vector(x: state.size * Double(x), y: state.size * Double(y), z: 0)) {
                    /*
                     Decoration(color: .gray.opacity(0.1), lineStyle: .dashed(phase: 0, lengths: [5, 5]), hidden: y + 1 == yRange.upperBound) {
                     Polygon(vertices: [
                     Vector(-state.size / 2, -state.size / 2, 0),
                     Vector(+state.size / 2, -state.size / 2, 0),
                     Vector(+state.size / 2, +state.size / 2, 0),
                     Vector(-state.size / 2, +state.size / 2, 0),
                     ],
                     closed: true)
                     }
                     */

                    // top bottom holes
                    Decoration(hidden: false) {
                        // make all but the bottom have some extra space to fit two tabs
                        let extraSpace = y != 0 ? Vector(0, -state.thickness, 0) : Vector()
                        for flip in [true, false] {
                            Flip(at: Vector(0, -state.size / 2, 0), around: Vector(0, 1, 0), by: flip ? .pi : 0.0) {
                                Path {
                                    MoveTo(Vector(0,
                                                  -state.size / 2 + insideTabLength,
                                                  0))
                                    LineTo(Vector(state.fastenerHoleWidth / 2 - state.toothKeyRoundingRadius,
                                                  -state.size / 2 + insideTabLength,
                                                  0))

                                    AxisOrbitCounterClockwise(pivot: Vector(state.fastenerHoleWidth / 2 - state.toothKeyRoundingRadius,
                                                                            -state.size / 2 + state.insideTabLength - state.toothKeyRoundingRadius,
                                                                            0),
                                                              point: Vector(state.fastenerHoleWidth / 2 - state.toothKeyRoundingRadius,
                                                                            -state.size / 2 + insideTabLength,
                                                                            0),
                                                              angle: .pi / 2,
                                                              axis: Vector(0, 0, -1))

                                    LineTo(Vector(state.fastenerHoleWidth / 2,
                                                  -state.size / 2,
                                                  0) + extraSpace)

                                    AxisOrbitCounterClockwise(pivot: Vector(state.fastenerHoleWidth / 2 + state.toothReliefRadius,
                                                                            -state.size / 2,
                                                                            0) + extraSpace,
                                                              point: Vector(state.fastenerHoleWidth / 2,
                                                                            -state.size / 2,
                                                                            0) + extraSpace,
                                                              angle: .pi,
                                                              axis: Vector(0, 0, 1))
                                    LineTo(Vector(state.fastenerWidth / 2 - state.toothReliefRadius * 2 + state.toothClearence, -state.size / 2, 0) + extraSpace)

                                    AxisOrbitCounterClockwise(pivot: Vector(state.fastenerWidth / 2 - state.toothReliefRadius + state.toothClearence,
                                                                            -state.size / 2,
                                                                            0) + extraSpace,
                                                              point: Vector(state.fastenerWidth / 2 - state.toothReliefRadius * 2 + state.toothClearence,
                                                                            -state.size / 2,
                                                                            0) + extraSpace,
                                                              angle: .pi,
                                                              axis: Vector(0, 0, 1))

                                    LineTo(Vector(state.fastenerWidth / 2 + state.toothClearence,
                                                  -state.size / 2 + state.hookDepth + state.toothClearence * 2 + state.thickness,
                                                  0))

                                    AxisOrbitCounterClockwise(pivot: Vector(state.fastenerWidth / 2 + state.toothClearence - state.toothKeyRoundingRadius,
                                                                            -state.size / 2 + state.hookDepth + state.toothClearence * 2 + state.thickness,
                                                                            0),
                                                              point: Vector(state.fastenerWidth / 2 + state.toothClearence,
                                                                            -state.size / 2 + state.hookDepth + state.toothClearence * 2 + state.thickness,
                                                                            0),
                                                              angle: .pi / 2,
                                                              axis: Vector(0, 0, 1))

                                    LineTo(Vector(0,
                                                  -state.size / 2 + state.hookDepth + state.toothClearence * 2 + state.thickness + state.toothKeyRoundingRadius,
                                                  0))
                                }
                            }
                        }
                    }

                    // left/right holes
                    Decoration(hidden: y + 1 == yRange.upperBound) {
                        // far left
                        if x == xRange.lowerBound {
                            RelievedSlot(start: Vector(-state.size / 2 + state.thickness / 2 + state.holeClearence / 2,
                                                       -state.hookWidth / 2 + state.hookDepth,
                                                       0),
                                         end: Vector(-state.size / 2 + state.thickness / 2 + state.holeClearence / 2,
                                                     +state.hookWidth / 2 + state.holeClearence * 2 + state.hookDepth,
                                                     0),
                                         width: -Vector(state.thickness / 2 + state.holeClearence / 2,
                                                        0,
                                                        0),
                                         reliefDepth: state.toothReliefDepth,
                                         reliefRadius: state.toothReliefRadius)
                        }

                        // far right
                        if x == xRange.upperBound - 1 {
                            RelievedSlot(start: Vector(+state.size / 2 - state.thickness / 2 - state.holeClearence / 2,
                                                       -state.hookWidth / 2 + state.hookDepth,
                                                       0),
                                         end: Vector(+state.size / 2 - state.thickness / 2 - state.holeClearence / 2,
                                                     +state.hookWidth / 2 + state.holeClearence * 2 + state.hookDepth,
                                                     0),
                                         width: -Vector(state.thickness / 2 + state.holeClearence / 2,
                                                        0,
                                                        0),
                                         reliefDepth: state.toothReliefDepth,
                                         reliefRadius: state.toothReliefRadius)
                        }

                        // middle
                        if x != xRange.lowerBound {
                            RelievedSlot(start: Vector(-state.size / 2,
                                                       -state.hookWidth / 2 + state.hookDepth,
                                                       0),
                                         end: Vector(-state.size / 2,
                                                     +state.hookWidth / 2 + state.holeClearence * 2 + state.hookDepth,
                                                     0),
                                         width: -Vector(state.thickness + state.holeClearence,
                                                        0,
                                                        0),
                                         reliefDepth: state.toothReliefDepth,
                                         reliefRadius: state.toothReliefRadius)
                        }
                    }
                }
            }
        }
    }
}
