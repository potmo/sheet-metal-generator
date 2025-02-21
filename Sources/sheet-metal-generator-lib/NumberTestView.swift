import AppKit
import CanvasRender
import Cocoa
import Combine
import Foundation
import simd
import SwiftUI

public struct NumberTestView: ShapeMaker {
    public typealias StateType = InputState

    public init() {
    }

    @CanvasBuilder
    public func shapes(from state: StateType) -> [DrawableShape] {
        PathNumber(number: "0123456789",
                   topCorner: Vector(0, 0, 0),
                   sideDirection: Vector(1, 0, 0),
                   downDirection: Vector(0, -1, 0),
                   scale: 1)

        Offset(Vector(0, -1.5, 0)) {
            Flip(at: Vector(5, -0.5, 0), around: Vector(0, 0, 1), by: .pi) {
                PathNumber(number: "9876543210",
                           topCorner: Vector(0, 0, 0),
                           sideDirection: Vector(1, 0, 0),
                           downDirection: Vector(0, -1, 0),
                           scale: 1)
            }
        }

        Offset(Vector(0, -3, 0)) {
            Flip(at: Vector(5, -0.5, 0), around: Vector(0, 1, 0), by: .pi) {
                PathNumber(number: "9876543210",
                           topCorner: Vector(0, 0, 0),
                           sideDirection: Vector(1, 0, 0),
                           downDirection: Vector(0, -1, 0),
                           scale: 1)
            }
        }
    }
}
