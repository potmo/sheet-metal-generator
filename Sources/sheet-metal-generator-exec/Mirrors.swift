import CanvasRender
import Foundation

enum JsonNormals {
    static var normals: [MirrorNormal] {
        let decoder = JSONDecoder()

        let path = Bundle.module.path(forResource: "mini-normals", ofType: "json")
        let string = try! String(contentsOfFile: path!, encoding: String.Encoding.utf8)
        let data = string.data(using: .utf8)!

        do {
            return try decoder.decode([MirrorNormal].self, from: data)
        } catch {
            fatalError("error: \(error)")
        }
    }
}

struct MirrorNormal: Codable {
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
