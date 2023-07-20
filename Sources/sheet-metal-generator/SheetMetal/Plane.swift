import Foundation
import simd

struct Plane {
    /// v0 --- v1
    /// |            |
    /// v3 --- v2
    ///
    let vertex0: simd_double3
    let vertex1: simd_double3
    let vertex2: simd_double3
    let vertex3: simd_double3

    var normal: Vector {
        return Vector.normalFromClockwiseVertices(a: vertex0, b: vertex1, c: vertex2)
    }

    var verticies: [simd_double3] {
        return [vertex0, vertex1, vertex2, vertex3]
    }

    init(vertex0: simd_double3,
         vertex1: simd_double3,
         vertex2: simd_double3,
         vertex3: simd_double3) {
        self.vertex0 = vertex0
        self.vertex1 = vertex1
        self.vertex2 = vertex2
        self.vertex3 = vertex3
    }

    func extrude(thickness: Double) -> Sheet {
        return Sheet(extrudendFrom: self, thickness: thickness)
    }

    /// Construct a plane where the square corners is projected onto a tilted plane that is then rotated back into the origin plane
    init(fitting size: Double,
         rotatedAroundX angleAroundX: Double,
         andY angleAroundY: Double) {
        let xRads = angleAroundX.degreesToRadians
        let yRads = angleAroundY.degreesToRadians
        let xRotation = Quat(angle: xRads, axis: Vector(x: 1, y: 0, z: 0))
        let yRotation = Quat(angle: yRads, axis: Vector(x: 0, y: 1, z: 0))
        let rotation = yRotation * xRotation

        let upperLeft = Vector(x: -size / 2, y: -size / 2, z: size * 2)
        let upperRight = Vector(x: size / 2, y: -size / 2, z: size * 2)
        let lowerRight = Vector(x: size / 2, y: size / 2, z: size * 2)
        let lowerLeft = Vector(x: -size / 2, y: size / 2, z: size * 2)

        let down = Vector(x: 0, y: 0, z: -1)

        let planeNormal = rotation.act(Vector(x: 0, y: 0, z: 1))
        let planeOrigin = Vector(x: 0, y: 0, z: 0)

        guard let upperLeftHit = down.intersectPlane2(normal: planeNormal, planeOrigin: planeOrigin, rayOrigin: upperLeft) else {
            fatalError("upperLeftHit does not have a hit point on the plane")
        }
        guard let upperRightHit = down.intersectPlane2(normal: planeNormal, planeOrigin: planeOrigin, rayOrigin: upperRight) else {
            fatalError("upperRightHit does not have a hit point on the plane")
        }
        guard let lowerRightHit = down.intersectPlane2(normal: planeNormal, planeOrigin: planeOrigin, rayOrigin: lowerRight) else {
            fatalError("lowerRightHit does not have a hit point on the plane")
        }
        guard let lowerLeftHit = down.intersectPlane2(normal: planeNormal, planeOrigin: planeOrigin, rayOrigin: lowerLeft) else {
            fatalError("lowerLeftHit does not have a hit point on the plane")
        }

        /*
         //rotate the plane back into the xy plane

         let upperLeftResult = rotation.inverse.act(upperLeftHit - planeOrigin)
         let upperRightResult = rotation.inverse.act(upperRightHit - planeOrigin)
         let lowerRightResult = rotation.inverse.act(lowerRightHit - planeOrigin)
         let lowerLeftResult = rotation.inverse.act(lowerLeftHit - planeOrigin)
         */

        self.init(vertex0: upperLeftHit - planeOrigin,
                  vertex1: upperRightHit - planeOrigin,
                  vertex2: lowerRightHit - planeOrigin,
                  vertex3: lowerLeftHit - planeOrigin)
    }

    func offsetted(by offsetVector: Vector) -> Plane {
        return Plane(vertex0: vertex0 + offsetVector,
                     vertex1: vertex1 + offsetVector,
                     vertex2: vertex2 + offsetVector,
                     vertex3: vertex3 + offsetVector)
    }
}
