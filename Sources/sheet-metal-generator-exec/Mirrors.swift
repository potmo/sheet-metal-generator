import CanvasRender
import Foundation
import simd

enum JsonNormals {
    static var normals: [MirrorNormal] {
        let decoder = JSONDecoder()

        let path = Bundle.module.path(forResource: "normals", ofType: "json")
        let string = try! String(contentsOfFile: path!, encoding: String.Encoding.utf8)
        let data = string.data(using: .utf8)!

        do {
            return try decoder.decode([MirrorNormal].self, from: data)
        } catch {
            fatalError("error: \(error)")
        }
    }

    static func testNormals(size: Double) -> [MirrorNormal] {
        var normals: [MirrorNormal] = []
        let maxDist = 3.0 * size
        let plateCenter = Vector(2.0, 2.0, 0).scaled(by: size)
        for y in 0 ..< 5 {
            for x in 0 ..< 5 {
                if x == 2, y == 2 {
                    let mirror = MirrorNormal(mirror: 1,
                                              x: x,
                                              y: y,
                                              normal: Vector(0, 0, 1))
                    normals.append(mirror)
                    continue
                }

                // let dist = abs(x - 3) > abs(y - 3) ? Double(abs(x - 3)) : Double(abs(y - 3))

                let mirrorCenterPoint = Vector(Double(x), Double(y), 0).scaled(by: size)
                let dist = mirrorCenterPoint.distance(to: plateCenter)
                let distScaled = dist / maxDist
                let directionToCenter = (plateCenter - mirrorCenterPoint).normalized
                let rotationAxis = directionToCenter.cross(Vector(0, 0, 1))

                let rotation = simd_quatd(angle: 20.0.degreesToRadians * distScaled, axis: rotationAxis)
                let normal = rotation.act(Vector(0, 0, 1))

                let mirror = MirrorNormal(mirror: 1, x: x, y: y, normal: normal)
                normals.append(mirror)

                print("x: \(x), y: \(y), normal: \(normal.toFixed(2)), distScaled: \(distScaled), \(dist)")
            }
        }
        return normals
    }
}

struct MirrorNormal: Codable {
    let mirror: Int
    let x: Int
    let y: Int
    let normal: Vector

    init(mirror: Int, x: Int, y: Int, normal: Vector) {
        self.mirror = mirror
        self.x = x
        self.y = y
        self.normal = normal
    }

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
