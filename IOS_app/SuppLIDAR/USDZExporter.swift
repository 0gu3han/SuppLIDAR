import SceneKit
import UIKit

/// Converts the same mesh data used by GLBWriter into a USDZ file via SceneKit.
/// SceneKit's `write(to:)` exports USDZ natively on iOS 12+ — no external tools needed.
enum USDZExporter {

    static func write(meshes: [GLBWriter.Mesh], to url: URL) -> Bool {
        let scene = SCNScene()
        for mesh in meshes {
            guard let geo = geometry(from: mesh) else { continue }
            scene.rootNode.addChildNode(SCNNode(geometry: geo))
        }
        return scene.write(to: url, options: nil, delegate: nil, progressHandler: nil)
    }

    private static func geometry(from mesh: GLBWriter.Mesh) -> SCNGeometry? {
        guard mesh.vertexCount > 0, mesh.indexCount > 0 else { return nil }

        let positions = SCNGeometrySource(
            data: mesh.positions, semantic: .vertex,
            vectorCount: mesh.vertexCount, usesFloatComponents: true,
            componentsPerVector: 3, bytesPerComponent: 4,
            dataOffset: 0, dataStride: 12)

        let normals = SCNGeometrySource(
            data: mesh.normals, semantic: .normal,
            vectorCount: mesh.vertexCount, usesFloatComponents: true,
            componentsPerVector: 3, bytesPerComponent: 4,
            dataOffset: 0, dataStride: 12)

        let uvs = SCNGeometrySource(
            data: mesh.uvs, semantic: .texcoord,
            vectorCount: mesh.vertexCount, usesFloatComponents: true,
            componentsPerVector: 2, bytesPerComponent: 4,
            dataOffset: 0, dataStride: 8)

        let element = SCNGeometryElement(
            data: mesh.indices, primitiveType: .triangles,
            primitiveCount: mesh.indexCount / 3, bytesPerIndex: 4)

        let geo = SCNGeometry(sources: [positions, normals, uvs], elements: [element])

        let mat = SCNMaterial()
        mat.isDoubleSided = true
        mat.lightingModel = .lambert
        mat.diffuse.contents = mesh.texture
            ?? UIColor(red: 0.55, green: 0.57, blue: 0.62, alpha: 1)
        geo.materials = [mat]
        return geo
    }
}
