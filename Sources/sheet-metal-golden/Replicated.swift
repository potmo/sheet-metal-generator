// Types replicated verbatim (behaviour-wise) from the app target `sheet-metal-generator-exec`,
// where they are private/internal and therefore not importable:
//   - StaticCamera, StateObjectCamera  (sheet-metal-generator.swift)
//   - MirrorNormal, JsonNormals.normals (Mirrors.swift)
// Keep these in sync with the app if the app changes.

import CanvasRender
import Foundation
@testable import sheet_metal_generator_lib
import simd

struct StaticCamera: PerspectiveCamera {
    let position: Vector
    let rotation: Quat

    init(position: Vector, rotation: Quat) {
        self.position = position
        self.rotation = rotation
    }

    init(position: Vector, lookDirection: Vector) {
        self.position = position
        self.rotation = Quat(from: Vector(1, 0, 0), to: lookDirection.normalized)
    }
}

struct StateObjectCamera: PerspectiveCamera {
    private let state: InputState
    init(state: InputState) {
        self.state = state
    }

    var position: Vector {
        return Vector(0, 0, 0)
    }

    var rotation: Quat {
        let cameraOrbit = Quat(angle: state.cameraOrbit.degreesToRadians, axis: Vector(0, 0, 1))
        let cameraTilt = Quat(angle: -state.cameraTilt.degreesToRadians, axis: cameraOrbit.act(Vector(1, 0, 0)))
        return cameraTilt * cameraOrbit
    }
}

struct MirrorNormal: Decodable {
    let mirror: Int
    let x: Int
    let y: Int
    let normal: Vector

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.mirror = try container.decode(Int.self, forKey: .mirror)
        self.x = try container.decode(Int.self, forKey: .x)
        self.y = try container.decode(Int.self, forKey: .y)
        let normalContainer = try container.nestedContainer(keyedBy: NormalCodingKeys.self, forKey: .normal)
        let x = try normalContainer.decode(Double.self, forKey: .x)
        let y = try normalContainer.decode(Double.self, forKey: .y)
        let z = try normalContainer.decode(Double.self, forKey: .z)
        self.normal = Vector(x, y, z)
    }

    enum CodingKeys: CodingKey {
        case mirror
        case x
        case y
        case normal
    }

    enum NormalCodingKeys: CodingKey {
        case x
        case y
        case z
    }
}

enum JsonNormals {
    /// The app reads `normals.json` from its resource bundle. The golden tool reads the very same
    /// file from the app target's source directory (resolved relative to this source file).
    static var defaultPath: String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // sheet-metal-golden
            .deletingLastPathComponent() // Sources
            .appendingPathComponent("sheet-metal-generator-exec/Resources/normals.json")
            .path
    }

    static func load(path: String) -> [MirrorNormal] {
        let string = try! String(contentsOfFile: path, encoding: String.Encoding.utf8)
        let data = string.data(using: .utf8)!
        do {
            return try JSONDecoder().decode([MirrorNormal].self, from: data)
        } catch {
            fatalError("error: \(error)")
        }
    }
}
