import CanvasRender
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

    var vertices: [simd_double3] {
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

    init(vertices: [Vector]) {
        self.vertex0 = vertices[0]
        self.vertex1 = vertices[1]
        self.vertex2 = vertices[2]
        self.vertex3 = vertices[3]
    }

    func extrude(thickness: Double) -> Sheet {
        return Sheet(extrudendFrom: self, thickness: thickness)
    }

    /// Construct a plane where the square corners is projected onto a tilted plane that is then rotated back into the origin plane
    init(fitting size: Double,
         rotatedAroundX angleAroundX: Double,
         andY angleAroundY: Double,
         rotatedBackToXyPlane: Bool = false) {
        let xRads = angleAroundX.degreesToRadians
        let yRads = angleAroundY.degreesToRadians
        let xRotation = Quat(angle: xRads, axis: Vector(x: 1, y: 0, z: 0))
        let yRotation = Quat(angle: yRads, axis: Vector(x: 0, y: 1, z: 0))
        let rotation = yRotation * xRotation

        let upperLeft = Vector(x: -size / 2, y: size / 2, z: size * 5)
        let upperRight = Vector(x: size / 2, y: size / 2, z: size * 5)
        let lowerRight = Vector(x: size / 2, y: -size / 2, z: size * 5)
        let lowerLeft = Vector(x: -size / 2, y: -size / 2, z: size * 5)

        let down = Vector(x: 0, y: 0, z: -1)

        let planeNormal = rotation.act(Vector(x: 0, y: 0, z: 1))
        let planeOrigin = Vector(x: 0, y: 0, z: 0)

        guard let upperLeftHit = down.intersectPlane(normal: planeNormal, planeOrigin: planeOrigin, rayOrigin: upperLeft) else {
            fatalError("upperLeftHit does not have a hit point on the plane")
        }
        guard let upperRightHit = down.intersectPlane(normal: planeNormal, planeOrigin: planeOrigin, rayOrigin: upperRight) else {
            fatalError("upperRightHit does not have a hit point on the plane")
        }
        guard let lowerRightHit = down.intersectPlane(normal: planeNormal, planeOrigin: planeOrigin, rayOrigin: lowerRight) else {
            fatalError("lowerRightHit does not have a hit point on the plane")
        }
        guard let lowerLeftHit = down.intersectPlane(normal: planeNormal, planeOrigin: planeOrigin, rayOrigin: lowerLeft) else {
            fatalError("lowerLeftHit does not have a hit point on the plane")
        }

        // rotate the plane back into the xy plane
        if rotatedBackToXyPlane {
            let upperLeftResult = rotation.inverse.act(upperLeftHit - planeOrigin)
            let upperRightResult = rotation.inverse.act(upperRightHit - planeOrigin)
            let lowerRightResult = rotation.inverse.act(lowerRightHit - planeOrigin)
            let lowerLeftResult = rotation.inverse.act(lowerLeftHit - planeOrigin)

            self.init(vertex0: upperLeftResult.with(z: 0),
                      vertex1: upperRightResult.with(z: 0),
                      vertex2: lowerRightResult.with(z: 0),
                      vertex3: lowerLeftResult.with(z: 0))
        } else {
            self.init(vertex0: upperLeftHit - planeOrigin,
                      vertex1: upperRightHit - planeOrigin,
                      vertex2: lowerRightHit - planeOrigin,
                      vertex3: lowerLeftHit - planeOrigin)
        }
    }

    func offsetted(by offsetVector: Vector) -> Plane {
        return Plane(vertex0: vertex0 + offsetVector,
                     vertex1: vertex1 + offsetVector,
                     vertex2: vertex2 + offsetVector,
                     vertex3: vertex3 + offsetVector)
    }

    func resizedNorth(by amount: Double) -> Plane {
        return Plane(vertex0: vertex0 + (vertex0 - vertex3).normalized.scaled(by: amount),
                     vertex1: vertex1 + (vertex1 - vertex2).normalized.scaled(by: amount),
                     vertex2: vertex2,
                     vertex3: vertex3)
    }

    func resizedEast(by amount: Double) -> Plane {
        return Plane(vertex0: vertex0,
                     vertex1: vertex1 + (vertex1 - vertex0).normalized.scaled(by: amount),
                     vertex2: vertex2 + (vertex2 - vertex3).normalized.scaled(by: amount),
                     vertex3: vertex3)
    }

    func resizedWest(by amount: Double) -> Plane {
        return Plane(vertex0: vertex0 + (vertex0 - vertex1).normalized.scaled(by: amount),
                     vertex1: vertex1,
                     vertex2: vertex2,
                     vertex3: vertex3 + (vertex3 - vertex2).normalized.scaled(by: amount))
    }

    func resizedSouth(by amount: Double) -> Plane {
        return Plane(vertex0: vertex0,
                     vertex1: vertex1,
                     vertex2: vertex2 + (vertex2 - vertex1).normalized.scaled(by: amount),
                     vertex3: vertex3 + (vertex3 - vertex0).normalized.scaled(by: amount))
    }

    var north: PlaneEdge {
        return PlaneEdge(plane: self,
                         vertex0index: 0,
                         vertex1index: 1)
    }

    var east: PlaneEdge {
        return PlaneEdge(plane: self,
                         vertex0index: 1,
                         vertex1index: 2)
    }

    var south: PlaneEdge {
        return PlaneEdge(plane: self,
                         vertex0index: 2,
                         vertex1index: 3)
    }

    var west: PlaneEdge {
        return PlaneEdge(plane: self,
                         vertex0index: 3,
                         vertex1index: 0)
    }

    func offsetVertex(_ vertex: Int, by vector: Vector) -> Plane {
        var newVertices = vertices // copy
        newVertices[vertex] += vector
        return Plane(vertices: newVertices)
    }
}

struct PlaneEdge {
    let plane: Plane
    let vertex0index: Int
    let vertex1index: Int

    init(plane: Plane, vertex0index: Int, vertex1index: Int) {
        self.plane = plane
        self.vertex0index = vertex0index
        self.vertex1index = vertex1index
    }

    var vertex0: Vector {
        return plane.vertices[vertex0index]
    }

    var vertex1: Vector {
        return plane.vertices[vertex1index]
    }

    var vertices: [Vector] {
        return [vertex0, vertex1]
    }

    var normal: Vector {
        return plane.normal.cross(direction)
    }

    var direction: Vector {
        return (vertex1 - vertex0).normalized
    }

    func resizedAlongNormal(by amount: Double) -> Plane {
        return plane
            .offsetVertex(vertex0index, by: normal.scaled(by: amount))
            .offsetVertex(vertex1index, by: normal.scaled(by: amount))
    }

    func resizedAlongSides(byDistanceAlongNormal amount: Double) -> Plane {
        let previousIndex = (vertex0index - 1) %% 4
        let nextIndex = (vertex1index + 1) %% 4

        let firstSide = plane.vertices[vertex0index] - plane.vertices[previousIndex]
        let secondSide = plane.vertices[vertex1index] - plane.vertices[nextIndex]

        let scaledVertex0 = plane.vertices[vertex0index] + normal.scaled(by: amount)
        let scaledVertex1 = plane.vertices[vertex1index] + normal.scaled(by: amount)

        let firstSideScaled = scaledVertex0 - plane.vertices[previousIndex]
        let secondSideScaled = scaledVertex1 - plane.vertices[nextIndex]

        let firstSideProjected = firstSideScaled.projected(onto: firstSide)
        let secondSideProjected = secondSideScaled.projected(onto: secondSide)

        let newPosition0 = plane.vertices[previousIndex] + firstSideProjected
        let newPosition1 = plane.vertices[nextIndex] + secondSideProjected

        var newVertices = plane.vertices // copy

        newVertices[vertex0index] = newPosition0
        newVertices[vertex1index] = newPosition1

        return Plane(vertices: newVertices)
    }

    func pushPulledInNormalDirection(by amount: Double) -> Plane {
        let newVertex0index = (vertex0index - 1) %% 4
        let newVertex1index = (vertex1index + 1) %% 4

        var vertices = Array(repeating: Vector(), count: 4)

        // these are adjecent to the start
        vertices[newVertex0index] = plane.vertices[vertex0index]
        vertices[newVertex1index] = plane.vertices[vertex1index]

        // these are opposite of the start
        vertices[vertex0index] = vertices[newVertex0index] + normal * amount
        vertices[vertex1index] = vertices[newVertex1index] + normal * amount

        return Plane(vertices: vertices)
    }

    func pushPulled(by amount: Double, in direction: Vector) -> Plane {
        let previousIndex = (vertex0index - 1) %% 4
        let nextIndex = (vertex1index + 1) %% 4

        let firstSide = plane.vertices[vertex0index] - plane.vertices[previousIndex]
        let secondSide = plane.vertices[vertex1index] - plane.vertices[nextIndex]

        let midPoint = plane.vertices[vertex0index] + (plane.vertices[vertex1index] - plane.vertices[vertex0index]).scaled(by: 0.5)

        let directionVector = direction.scaled(by: amount)

        // get the corners projected onto the mid line
        let firstProjection = (plane.vertices[vertex0index] - midPoint).projected(onto: directionVector)
        let secondProjection = (plane.vertices[vertex1index] - midPoint).projected(onto: directionVector)

        let newPosition0 = plane.vertices[vertex0index] + directionVector - firstProjection
        let newPosition1 = plane.vertices[vertex1index] + directionVector - secondProjection

        var vertices = plane.vertices // copy

        // these are adjecent to the start
        vertices[previousIndex] = plane.vertices[vertex0index]
        vertices[nextIndex] = plane.vertices[vertex1index]

        vertices[vertex0index] = newPosition0
        vertices[vertex1index] = newPosition1

        return Plane(vertices: vertices)
    }
}
