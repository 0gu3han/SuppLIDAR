import Foundation
import UIKit

/// Writes a binary glTF 2.0 (GLB) file from pre-built mesh data.
/// Each mesh carries its own photographic JPEG texture and projective UV coordinates.
enum GLBWriter {

    struct Mesh {
        var positions:   Data       // packed Float32 × 3, world space
        var normals:     Data       // packed Float32 × 3, world space
        var uvs:         Data       // packed Float32 × 2
        var indices:     Data       // packed UInt32
        var vertexCount: Int
        var indexCount:  Int        // triangleCount × 3
        var texture:     UIImage?   // best camera frame for this anchor
        var minPos:      (Float, Float, Float)
        var maxPos:      (Float, Float, Float)
    }

    // MARK: - Public

    static func write(meshes: [Mesh], to url: URL) -> Bool {
        guard !meshes.isEmpty else { return false }

        // ── 1. Build binary buffer ─────────────────────────────────────────────
        // Layout: [geom0-pos | geom0-norm | geom0-uv | geom0-idx | … | img0 | img1 | …]
        struct BVInfo { var offset: Int; var length: Int }
        var bvInfos = [BVInfo]()
        var bin     = Data()

        for mesh in meshes {
            for chunk in [mesh.positions, mesh.normals, mesh.uvs, mesh.indices] {
                align4(&bin)
                bvInfos.append(BVInfo(offset: bin.count, length: chunk.count))
                bin.append(chunk)
            }
        }

        // Embed JPEG textures after geometry
        var imgBVIdx = [Int?]()
        for mesh in meshes {
            if let img  = mesh.texture,
               let jpeg = resized(img, maxDim: 2048)?.jpegData(compressionQuality: 0.92) {
                align4(&bin)
                imgBVIdx.append(bvInfos.count)
                bvInfos.append(BVInfo(offset: bin.count, length: jpeg.count))
                bin.append(jpeg)
            } else {
                imgBVIdx.append(nil)
            }
        }
        align4(&bin)

        // ── 2. Build glTF JSON ─────────────────────────────────────────────────
        var jNodes     = [[String: Any]]()
        var jMeshes    = [[String: Any]]()
        var jMaterials = [[String: Any]]()
        var jTextures  = [[String: Any]]()
        var jImages    = [[String: Any]]()
        let jSamplers: [[String: Any]] = [[
            "magFilter": 9729, "minFilter": 9987,
            "wrapS": 10497,    "wrapT": 10497
        ]]
        var jAccessors = [[String: Any]]()
        var jBufViews  = [[String: Any]]()

        for (i, mesh) in meshes.enumerated() {
            jNodes.append(["mesh": i])

            let geoBVStart = jBufViews.count
            let geoBVBase  = i * 4
            let targets    = [34962, 34962, 34962, 34963]   // ARRAY/ELEMENT_ARRAY_BUFFER

            for j in 0..<4 {
                let bv = bvInfos[geoBVBase + j]
                jBufViews.append([
                    "buffer": 0, "byteOffset": bv.offset,
                    "byteLength": bv.length, "target": targets[j]
                ])
            }

            let accBase = jAccessors.count
            jAccessors.append([                             // POSITION
                "bufferView": geoBVStart, "componentType": 5126,
                "count": mesh.vertexCount, "type": "VEC3",
                "min": [mesh.minPos.0, mesh.minPos.1, mesh.minPos.2],
                "max": [mesh.maxPos.0, mesh.maxPos.1, mesh.maxPos.2]
            ])
            jAccessors.append([                             // NORMAL
                "bufferView": geoBVStart + 1, "componentType": 5126,
                "count": mesh.vertexCount, "type": "VEC3"
            ])
            jAccessors.append([                             // TEXCOORD_0
                "bufferView": geoBVStart + 2, "componentType": 5126,
                "count": mesh.vertexCount, "type": "VEC2"
            ])
            jAccessors.append([                             // indices
                "bufferView": geoBVStart + 3, "componentType": 5125,
                "count": mesh.indexCount, "type": "SCALAR"
            ])

            let matIdx = jMaterials.count
            if let bvIdx = imgBVIdx[i] {
                let texIdx        = jTextures.count
                let imgIdx        = jImages.count
                let imgBufViewIdx = jBufViews.count
                let bv            = bvInfos[bvIdx]
                jBufViews.append([
                    "buffer": 0, "byteOffset": bv.offset, "byteLength": bv.length
                ])
                jImages.append(["bufferView": imgBufViewIdx, "mimeType": "image/jpeg"])
                jTextures.append(["sampler": 0, "source": imgIdx])
                jMaterials.append([
                    "pbrMetallicRoughness": [
                        "baseColorTexture": ["index": texIdx],
                        "metallicFactor": 0.0, "roughnessFactor": 1.0
                    ],
                    "doubleSided": true
                ])
            } else {
                jMaterials.append([
                    "pbrMetallicRoughness": [
                        "baseColorFactor": [0.55, 0.57, 0.62, 1.0],
                        "metallicFactor": 0.0, "roughnessFactor": 1.0
                    ],
                    "doubleSided": true
                ])
            }

            jMeshes.append(["primitives": [[
                "attributes": [
                    "POSITION": accBase, "NORMAL": accBase + 1, "TEXCOORD_0": accBase + 2
                ],
                "indices":  accBase + 3,
                "material": matIdx
            ]]])
        }

        var json: [String: Any] = [
            "asset":       ["version": "2.0", "generator": "Mentis"],
            "scene":       0,
            "scenes":      [["nodes": Array(0..<meshes.count)]],
            "nodes":       jNodes,
            "meshes":      jMeshes,
            "materials":   jMaterials,
            "accessors":   jAccessors,
            "bufferViews": jBufViews,
            "buffers":     [["byteLength": bin.count]],
            "samplers":    jSamplers
        ]
        if !jTextures.isEmpty { json["textures"] = jTextures }
        if !jImages.isEmpty   { json["images"]   = jImages   }

        guard let rawJSON = try? JSONSerialization.data(withJSONObject: json) else { return false }

        var jsonChunk = rawJSON
        while jsonChunk.count % 4 != 0 { jsonChunk.append(0x20) }

        // ── 3. Assemble GLB ───────────────────────────────────────────────────
        var glb = Data()
        glb.append(contentsOf: [0x67, 0x6C, 0x54, 0x46])
        appendU32(&glb, 2)
        appendU32(&glb, 0)

        appendU32(&glb, UInt32(jsonChunk.count))
        appendU32(&glb, 0x4E4F534A)
        glb.append(jsonChunk)

        appendU32(&glb, UInt32(bin.count))
        appendU32(&glb, 0x004E4942)
        glb.append(bin)

        let totalLen = UInt32(glb.count)
        withUnsafeBytes(of: totalLen.littleEndian) { glb.replaceSubrange(8..<12, with: $0) }

        do { try glb.write(to: url); return true }
        catch { return false }
    }

    // MARK: - Helpers

    private static func align4(_ data: inout Data) {
        while data.count % 4 != 0 { data.append(0) }
    }

    private static func appendU32(_ data: inout Data, _ value: UInt32) {
        var le = value.littleEndian
        withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
    }

    static func resized(_ image: UIImage, maxDim: CGFloat) -> UIImage? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image }
        let scale = Swift.min(maxDim / size.width, maxDim / size.height, 1.0)
        if scale >= 1.0 { return image }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, true, 1.0)
        defer { UIGraphicsEndImageContext() }
        image.draw(in: CGRect(origin: .zero, size: newSize))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
