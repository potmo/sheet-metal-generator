import CanvasRender
import CoreGraphics
import Foundation

/// Fixed, locale independent number format used by the recording target.
/// `%.6f` via `String(format:)` (no locale argument => POSIX formatting), with -0 normalised to 0.
func goldenNumber(_ value: Double) -> String {
    if value.isNaN { return "nan" }
    if value.isInfinite { return value < 0 ? "-inf" : "inf" }
    let string = String(format: "%.6f", value)
    if string == "-0.000000" {
        return "0.000000"
    }
    return string
}

func goldenNumber(_ value: CGFloat) -> String {
    goldenNumber(Double(value))
}

func goldenPoint(_ point: CGPoint) -> String {
    "\(goldenNumber(point.x)) \(goldenNumber(point.y))"
}

/// Logs every `RenderTarget` protocol call, one per line, in call order.
final class RecordingRenderTarget: RenderTarget {
    private(set) var lines: [String] = []

    var text: String {
        lines.joined(separator: "\n") + "\n"
    }

    func addLine(to point: CGPoint) {
        lines.append("line \(goldenPoint(point))")
    }

    func move(to point: CGPoint) {
        lines.append("move \(goldenPoint(point))")
    }

    func beginPath(id: String?) {
        if let id {
            lines.append("begin id=\(id.debugDescription)")
        } else {
            lines.append("begin id=nil")
        }
    }

    func strokePath() {
        lines.append("stroke")
    }

    func fillPath() {
        lines.append("fill")
    }

    func closePath() {
        lines.append("close")
    }

    func setLineDash(phase: CGFloat, lengths: [CGFloat]) {
        lines.append("dash phase=\(goldenNumber(phase)) lengths=[\(lengths.map(goldenNumber).joined(separator: ","))]")
    }

    func setStrokeColor(_ color: CGColor) {
        let components = color.components ?? []
        lines.append("color n=\(color.numberOfComponents) [\(components.map(goldenNumber).joined(separator: ","))]")
    }

    func setLineWidth(_ width: CGFloat) {
        lines.append("width \(goldenNumber(width))")
    }

    func text(_ string: String, position: CGPoint, size: CGFloat) {
        lines.append("text \(string.debugDescription) at=\(goldenPoint(position)) size=\(goldenNumber(size))")
    }

    func arc(center: CGPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat, counterClockwise: Bool) {
        lines.append("arc c=\(goldenPoint(center)) r=\(goldenNumber(radius)) start=\(goldenNumber(startAngle)) end=\(goldenNumber(endAngle)) ccw=\(counterClockwise ? 1 : 0)")
    }

    func addComment(_ string: String) {
        lines.append("comment \(string.debugDescription)")
    }

    func circle(center: CGPoint, radius: CGFloat) {
        lines.append("circle c=\(goldenPoint(center)) r=\(goldenNumber(radius))")
    }
}
