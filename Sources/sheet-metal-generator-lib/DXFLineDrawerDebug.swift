import AppKit
import CanvasRender
import Cocoa
import Combine
import Foundation
import simd
import SwiftUI

public struct DXFLineDrawerDebug: ShapeMaker {
    public typealias StateType = InputState
    private let target: DXFLWLineRenderTarget

    public init(target: DXFLWLineRenderTarget) {
        self.target = target
    }

    public func shapes(from state: StateType) -> [DrawableShape] {
        var shapes: [DrawableShape] = []
        let colors: [CanvasColor] = [.red, .blue, .green, .yellow, .orange, .purple, .pink, .black]

        let allNodes = target.openNodes + target.closedNodes
        for (index, node) in allNodes.enumerated() {
            let block = CodeBlock { context in
                context.renderTarget.beginPath()
                context.renderTarget.setStrokeColor(colors[index % colors.count].cgColor)
                context.renderTarget.move(to: context.transform(node.head.content.startPoint.vector2D.xyVector3D))

                for content in node.array {
                    content.content.draw(in: context)
                }

                context.renderTarget.strokePath()
            }
            shapes.append(block)
        }

        return shapes
    }
}
