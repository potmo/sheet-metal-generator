import AppKit
import CanvasRender
import Cocoa
import Combine
import Foundation
import simd
import SwiftUI

public struct DXFLineDrawerDebug: ShapeMaker {
    public typealias StateType = InputState
    private let target: DXFRenderTarget

    public init(target: DXFRenderTarget) {
        self.target = target
    }

    public func shapes(from state: StateType) -> [DrawableShape] {
        var shapes: [DrawableShape] = []
        let colors: [CanvasColor] = [.red, .blue, .green, .yellow, .orange, .purple, .pink, .black]

        // every joined polyline in its own color, its points treated as positions in the XY plane
        for (index, polyline) in target.polylines.enumerated() {
            let block = CodeBlock { context in
                context.renderTarget.beginPath()
                context.renderTarget.setStrokeColor(colors[index % colors.count].cgColor)
                context.renderTarget.move(to: context.transform(polyline.segments[0].startPoint.vector2D.xyVector3D))

                for segment in polyline.segments {
                    for point in segment.points().dropFirst() {
                        context.renderTarget.addLine(to: context.transform(point.vector2D.xyVector3D))
                    }
                }
                if polyline.closed {
                    context.renderTarget.closePath()
                }

                context.renderTarget.strokePath()
            }
            shapes.append(block)
        }

        return shapes
    }
}
