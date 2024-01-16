import AppKit
import CanvasRender
import Foundation
import simd

struct OrbitTestView: ShapeMaker {
    typealias StateType = InputState

    @CanvasBuilder
    func shapes(from state: InputState) -> [DrawableShape] {
        let state = state.frozen
        
        Decoration(hidden: false) {
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

        /*
         OrbitCounterClockwise(pivot: Vector(0, 0, 0),
               point: Vector(5, 0, 0),
               rotation: Quat(angle: .pi, axis: Vector(0, 0, 1)))

         OrbitCounterClockwise(pivot: Vector(0 + 11 * 1, 0, 0),
               point: Vector(5 + 11 * 1, 0, 0),
               rotation: Quat(angle: .pi * 2, axis: Vector(0, 0, 1)))

         */

        for (index, angle) in stride(from: 0, through: .pi * 2, by: .pi * 2 * 0.1).enumerated() {
            if index == 5 || true {
                let offset = Double(index) * 11.0
                let pivot = Vector(offset, 0, 0)
                let startPoint = pivot + Vector(1, 1, 0).normalized.scaled(by: 5)
                let rotation = Quat(angle: angle, axis: Vector(0, 0, 1))
                let endPoint = pivot + rotation.act(startPoint - pivot)

                // let clockwiseNormal = Vector.normalFromClockwiseVertices(a: startPoint, pivot: pivot, b: endPoint)
                let directionA = (startPoint - pivot).normalized
                let directionB = (endPoint - pivot).normalized

                let rot2 = Quat(from: directionA, to: directionB).axis.isNaN ?
                    Quat(angle: Quat(from: directionA, to: directionB).angle, axis: Vector(0, 0, 1))
                    :
                    Quat(from: directionA, to: directionB)

                let angle = rot2.axis.isNaN ?
                    0
                    :
                    (rot2.axis.dot(Vector(0, 0, 1)) >= 0) ?
                    rot2.angle
                    :
                    .pi * 2 - rot2.angle

                let axis = Vector(0, 0, 1)

                // flip the angles if its rotating the other way
                let rot3 = Quat(angle: angle, axis: axis)

                Decoration(color: .green) {
                    AxisOrbitCounterClockwise(pivot: pivot,
                              point: startPoint,
                              angle: angle,
                              axis: Vector(0, 0, 1))

                    AxisOrbitCounterClockwise(pivot: pivot + Vector(0, -15, 0),
                              point: startPoint + Vector(0, -15, 0),
                              angle: angle,
                              axis: Vector(0, 0, -1))
                }

                OrbitCounterClockwise(pivot: pivot + Vector(0, -30, 0),
                      point: startPoint + Vector(0, -30, 0),
                      rotation: rot3)

                // inverted axis
                OrbitCounterClockwise(pivot: pivot + Vector(0, -45, 0),
                      point: startPoint + Vector(0, -45, 0),
                      rotation: Quat(angle: rot3.angle, axis: rot3.axis.scaled(by: -1)))

                // off axis

                OrbitCounterClockwise(pivot: pivot + Vector(0, -60, 0),
                      point: startPoint + Vector(0, -60, 0),
                      rotation: Quat(angle: rot3.angle, axis: (rot3.axis + Vector(0.1, 0, 0)).normalized),
                      arcResolutuon: 2)

                OrbitCounterClockwise(pivot: pivot + Vector(0, -75, 0),
                      point: startPoint + Vector(0, -75, 0),
                      rotation: Quat(angle: rot3.angle, axis: (rot3.axis.scaled(by: -1) + Vector(0.1, 0, 0)).normalized),
                      arcResolutuon: 2)
                
                Decoration(color: .blue.opacity(0.2)) {
                    Arrow(from: pivot, to: startPoint)
                    Arrow(from: pivot, to: endPoint)

                    Circle(center: Vector(offset, 0, 0) + rot3.act(Vector(5, 0, 0)), radius: 5)
                }

                TextString(center: pivot + Vector(0, 7, 0), text: rot3.angle.radiansToDegrees.toFixed(2), size: 10)
                TextString(center: pivot + Vector(0, 12, 0), text: rot3.axis.toFixed(2), size: 10)
            }
        }
    }
}
