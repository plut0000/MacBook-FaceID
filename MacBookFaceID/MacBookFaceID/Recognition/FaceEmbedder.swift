import CoreML
import CoreVideo
import Foundation
import Vision

enum FaceAnalysisError: LocalizedError {
    case noFace
    case multipleFaces
    case lowQuality
    case noEmbedding
    case engineMismatch

    var errorDescription: String? {
        switch self {
        case .noFace:
            return "No face detected. Look at the camera."
        case .multipleFaces:
            return "More than one face is visible. Enroll alone."
        case .lowQuality:
            return "Face capture is too blurry or dark. Move closer."
        case .noEmbedding:
            return "Could not build a face embedding from this frame."
        case .engineMismatch:
            return "Saved embeddings were made with a different engine. Please re-enroll."
        }
    }
}

struct FaceEmbedding: Codable, Equatable, Sendable {
    var version: Int
    var engine: String
    var values: [Float]

    static let currentVersion = 2
}

struct FaceFrameAnalysis: Sendable {
    let embedding: FaceEmbedding
    let boundingBox: CGRect
    let quality: Float
    let pose: PoseEstimate?
    let landmarks: LandmarkSnapshot
}

struct LandmarkSnapshot: Sendable {
    let leftEye: [CGPoint]
    let rightEye: [CGPoint]
    let nose: [CGPoint]
    let mouth: [CGPoint]
    let contour: [CGPoint]
    let medianBrightness: Float
    let glareRatio: Float
    let deviceFrameScore: Float
}

/// On-device embeddings. Default engine is an original 512-d descriptor of an
/// aligned 112×112 crop (DCT + LBP + landmarks). If the user places a
/// redistributable Core ML face-embedding model at the documented path, that
/// model is used instead. Apple’s `VNGenerateFaceFeaturePrintRequest` was
/// removed from recent SDKs. This project never vendors a third-party ArcFace
/// binary.
enum FaceEmbedder {
    static func analyze(
        _ image: CGImage,
        requireQuality: Float? = nil,
        allowMultiple: Bool = false
    ) throws -> FaceFrameAnalysis {
        let landmarksRequest = VNDetectFaceLandmarksRequest()
        let qualityRequest = VNDetectFaceCaptureQualityRequest()
        let rectangles = VNDetectRectanglesRequest()
        rectangles.minimumAspectRatio = 0.42
        rectangles.maximumAspectRatio = 0.78
        rectangles.minimumSize = 0.12
        rectangles.maximumObservations = 4

        let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
        try handler.perform([landmarksRequest, qualityRequest, rectangles])

        let faces = landmarksRequest.results ?? []
        if faces.isEmpty { throw FaceAnalysisError.noFace }
        if !allowMultiple && faces.count > 1 { throw FaceAnalysisError.multipleFaces }

        let face = faces.max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height }) ?? faces[0]
        let quality = qualityRequest.results?.first?.faceCaptureQuality ?? 0
        if let minimum = requireQuality, quality < minimum {
            throw FaceAnalysisError.lowQuality
        }

        guard let aligned = FaceAligner.alignedFace(from: image, observation: face) else {
            throw FaceAnalysisError.noEmbedding
        }

        let engine = CoreMLFaceModel.shared
        let values: [Float]
        let engineName: String
        if let engine {
            values = try engine.embed(aligned)
            engineName = AppConstants.embeddingEngineCoreML
        } else {
            values = try classicalEmbedding(aligned: aligned, face: face)
            engineName = AppConstants.embeddingEngineClassical
        }
        guard values.count == AppConstants.embeddingLength else {
            throw FaceAnalysisError.noEmbedding
        }

        let luma = luminanceStats(aligned)
        let snapshot = LandmarkSnapshot(
            leftEye: regionPoints(face.landmarks?.leftEye),
            rightEye: regionPoints(face.landmarks?.rightEye),
            nose: regionPoints(face.landmarks?.nose) + regionPoints(face.landmarks?.noseCrest),
            mouth: regionPoints(face.landmarks?.outerLips),
            contour: regionPoints(face.landmarks?.faceContour),
            medianBrightness: luma.median,
            glareRatio: luma.glare,
            deviceFrameScore: deviceFrameScore(face: face, rectangles: rectangles.results ?? [])
        )

        return FaceFrameAnalysis(
            embedding: FaceEmbedding(version: FaceEmbedding.currentVersion, engine: engineName, values: values),
            boundingBox: face.boundingBox,
            quality: quality,
            pose: PoseEstimator.estimate(from: face),
            landmarks: snapshot
        )
    }

    static func cosine(_ a: FaceEmbedding, _ b: FaceEmbedding) throws -> Float {
        guard a.version == b.version, a.engine == b.engine, a.values.count == b.values.count, !a.values.isEmpty else {
            throw FaceAnalysisError.engineMismatch
        }
        var dot: Float = 0
        var na: Float = 0
        var nb: Float = 0
        for index in a.values.indices {
            let x = a.values[index]
            let y = b.values[index]
            dot += x * y
            na += x * x
            nb += y * y
        }
        let denom = sqrt(na) * sqrt(nb)
        guard denom > 0 else { throw FaceAnalysisError.noEmbedding }
        return dot / denom
    }

    static func l2Normalize(_ input: [Float]) -> [Float] {
        var sum: Float = 0
        for value in input { sum += value * value }
        let norm = sqrt(max(sum, 1e-8))
        return input.map { $0 / norm }
    }

    // MARK: - Classical 512-d descriptor

    private static func classicalEmbedding(aligned: CGImage, face: VNFaceObservation) throws -> [Float] {
        let gray = grayscale(aligned, width: 64, height: 64)
        let dct = lowFrequencyDCT(gray, width: 64, height: 64, keep: 16) // 256
        let lbp = lbpHistogram(gray, width: 64, height: 64) // 128 after fold
        let geom = geometricDescriptor(face) // 128
        var combined: [Float] = []
        combined.reserveCapacity(AppConstants.embeddingLength)
        combined.append(contentsOf: dct)
        combined.append(contentsOf: lbp)
        combined.append(contentsOf: geom)
        while combined.count < AppConstants.embeddingLength {
            combined.append(0)
        }
        if combined.count > AppConstants.embeddingLength {
            combined = Array(combined.prefix(AppConstants.embeddingLength))
        }
        return l2Normalize(combined)
    }

    private static func geometricDescriptor(_ face: VNFaceObservation) -> [Float] {
        guard let landmarks = face.landmarks else {
            return [Float](repeating: 0, count: 128)
        }
        let regions: [(Int, VNFaceLandmarkRegion2D?)] = [
            (16, landmarks.faceContour),
            (6, landmarks.leftEye),
            (6, landmarks.rightEye),
            (6, landmarks.leftEyebrow),
            (6, landmarks.rightEyebrow),
            (8, landmarks.nose),
            (8, landmarks.outerLips),
            (4, landmarks.innerLips),
            (2, landmarks.medianLine)
        ]
        var points: [CGPoint] = []
        for (count, region) in regions {
            points.append(contentsOf: resample(regionPoints(region), count: count))
        }
        let left = PoseEstimator.centroid(landmarks.leftEye) ?? PoseEstimator.centroid(landmarks.leftPupil)
        let right = PoseEstimator.centroid(landmarks.rightEye) ?? PoseEstimator.centroid(landmarks.rightPupil)
        guard let left, let right else {
            return [Float](repeating: 0, count: 128)
        }
        let mid = CGPoint(x: (left.x + right.x) / 2, y: (left.y + right.y) / 2)
        let dx = right.x - left.x
        let dy = right.y - left.y
        let dist = max(hypot(dx, dy), 0.04)
        let angle = -atan2(dy, dx)
        let cosA = cos(angle)
        let sinA = sin(angle)

        var values: [Float] = []
        values.reserveCapacity(128)
        for point in points {
            let tx = point.x - mid.x
            let ty = point.y - mid.y
            let rx = (tx * cosA - ty * sinA) / dist
            let ry = (tx * sinA + ty * cosA) / dist
            values.append(Float(rx))
            values.append(Float(ry))
        }
        while values.count < 128 { values.append(0) }
        return Array(values.prefix(128))
    }

    private static func regionPoints(_ region: VNFaceLandmarkRegion2D?) -> [CGPoint] {
        guard let region, region.pointCount > 0 else { return [] }
        return (0..<region.pointCount).map { region.normalizedPoints[$0] }
    }

    private static func resample(_ source: [CGPoint], count: Int) -> [CGPoint] {
        if count <= 0 { return [] }
        if source.isEmpty { return Array(repeating: .zero, count: count) }
        if source.count == count { return source }
        if count == 1 { return [source[source.count / 2]] }
        if source.count == 1 { return Array(repeating: source[0], count: count) }

        var distances = [CGFloat](repeating: 0, count: source.count)
        for index in 1..<source.count {
            distances[index] = distances[index - 1] + hypot(
                source[index].x - source[index - 1].x,
                source[index].y - source[index - 1].y
            )
        }
        let total = max(distances.last ?? 0, 0.0001)
        var result: [CGPoint] = []
        result.reserveCapacity(count)
        for step in 0..<count {
            let target = total * CGFloat(step) / CGFloat(count - 1)
            var end = 1
            while end < distances.count - 1 && distances[end] < target {
                end += 1
            }
            let start = end - 1
            let span = max(distances[end] - distances[start], 0.0001)
            let t = (target - distances[start]) / span
            let a = source[start]
            let b = source[end]
            result.append(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
        }
        return result
    }

    private static func grayscale(_ image: CGImage, width: Int, height: Int) -> [Float] {
        var pixels = [UInt8](repeating: 0, count: width * height)
        let space = CGColorSpaceCreateDeviceGray()
        let ctx = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: space,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )
        ctx?.interpolationQuality = .high
        ctx?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixels.map { Float($0) / 255 }
    }

    /// Separable 2D DCT-II, keep the low-frequency `keep × keep` block.
    private static func lowFrequencyDCT(_ gray: [Float], width: Int, height: Int, keep: Int) -> [Float] {
        var rows = [Float](repeating: 0, count: height * width)
        for y in 0..<height {
            let row = Array(gray[y * width..<(y + 1) * width])
            let transformed = dct1D(row)
            for x in 0..<width {
                rows[y * width + x] = transformed[x]
            }
        }
        var cols = [Float](repeating: 0, count: height * width)
        for x in 0..<width {
            var column = [Float](repeating: 0, count: height)
            for y in 0..<height {
                column[y] = rows[y * width + x]
            }
            let transformed = dct1D(column)
            for y in 0..<height {
                cols[y * width + x] = transformed[y]
            }
        }
        var kept: [Float] = []
        kept.reserveCapacity(keep * keep)
        for y in 0..<keep {
            for x in 0..<keep {
                kept.append(cols[y * width + x])
            }
        }
        return kept
    }

    private static func dct1D(_ input: [Float]) -> [Float] {
        let n = input.count
        let factor = Float.pi / Float(n)
        var output = [Float](repeating: 0, count: n)
        for k in 0..<n {
            var sum: Float = 0
            for i in 0..<n {
                sum += input[i] * cos(factor * (Float(i) + 0.5) * Float(k))
            }
            let scale: Float = k == 0 ? sqrt(1 / Float(n)) : sqrt(2 / Float(n))
            output[k] = scale * sum
        }
        return output
    }

    private static func lbpHistogram(_ gray: [Float], width: Int, height: Int) -> [Float] {
        var bins = [Float](repeating: 0, count: 256)
        if width < 3 || height < 3 { return [Float](repeating: 0, count: 128) }
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let c = gray[y * width + x]
                var code = 0
                let neighbors: [(Int, Int)] = [
                    (x - 1, y - 1), (x, y - 1), (x + 1, y - 1), (x + 1, y),
                    (x + 1, y + 1), (x, y + 1), (x - 1, y + 1), (x - 1, y)
                ]
                for (bit, point) in neighbors.enumerated() {
                    if gray[point.1 * width + point.0] >= c {
                        code |= 1 << bit
                    }
                }
                bins[code] += 1
            }
        }
        let total = max(bins.reduce(0, +), 1)
        let normalized = bins.map { $0 / total }
        var folded = [Float](repeating: 0, count: 128)
        for index in 0..<128 {
            folded[index] = normalized[index] + normalized[index + 128]
        }
        return folded
    }

    private static func luminanceStats(_ image: CGImage) -> (median: Float, glare: Float) {
        let gray = grayscale(image, width: 32, height: 32)
        let sorted = gray.sorted()
        let median = sorted[sorted.count / 2]
        let glare = Float(gray.filter { $0 > 0.92 }.count) / Float(max(gray.count, 1))
        return (median, glare)
    }

    private static func deviceFrameScore(face: VNFaceObservation, rectangles: [VNRectangleObservation]) -> Float {
        let faceRect = face.boundingBox
        var best: Float = 0
        for rectangle in rectangles {
            let box = rectangle.boundingBox
            if box.contains(CGPoint(x: faceRect.midX, y: faceRect.midY)) && box.width * box.height > faceRect.width * faceRect.height * 1.15 {
                let aspect = box.width / max(box.height, 0.001)
                let phoneLike = aspect > 0.45 && aspect < 0.72 ? Float(1) : Float(0.4)
                best = max(best, phoneLike * Float(rectangle.confidence))
            }
        }
        return best
    }
}

/// Optional user-supplied Core ML embedder. Place a 112×112 face model at
/// `~/Library/Application Support/MacBookFaceID/FaceEmbedder.mlmodel` (or
/// `.mlpackage`). First multi-array output is treated as the embedding.
final class CoreMLFaceModel {
    static let shared: CoreMLFaceModel? = {
        CoreMLFaceModel.loadFromDisk()
    }()

    private let model: MLModel
    private let inputName: String
    private let outputName: String

    private init(model: MLModel, inputName: String, outputName: String) {
        self.model = model
        self.inputName = inputName
        self.outputName = outputName
    }

    static func documentedURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("MacBookFaceID", isDirectory: true)
    }

    private static func loadFromDisk() -> CoreMLFaceModel? {
        let folder = documentedURL()
        let candidates = [
            folder.appendingPathComponent("FaceEmbedder.mlmodel"),
            folder.appendingPathComponent("FaceEmbedder.mlpackage")
        ]
        for url in candidates where FileManager.default.fileExists(atPath: url.path) {
            do {
                let compiled = try MLModel.compileModel(at: url)
                let model = try MLModel(contentsOf: compiled)
                let inputs = Array(model.modelDescription.inputDescriptionsByName.keys)
                let outputs = Array(model.modelDescription.outputDescriptionsByName.keys)
                guard let input = inputs.first, let output = outputs.first else { continue }
                return CoreMLFaceModel(model: model, inputName: input, outputName: output)
            } catch {
                continue
            }
        }
        return nil
    }

    func embed(_ image: CGImage) throws -> [Float] {
        let buffer = try pixelBuffer(from: image, width: 112, height: 112)
        let provider = try MLDictionaryFeatureProvider(dictionary: [inputName: MLFeatureValue(pixelBuffer: buffer)])
        let out = try model.prediction(from: provider)
        guard let array = out.featureValue(for: outputName)?.multiArrayValue else {
            throw FaceAnalysisError.noEmbedding
        }
        var values = [Float]()
        values.reserveCapacity(array.count)
        switch array.dataType {
        case .float32:
            let pointer = array.dataPointer.bindMemory(to: Float.self, capacity: array.count)
            values.append(contentsOf: UnsafeBufferPointer(start: pointer, count: array.count))
        case .double:
            let pointer = array.dataPointer.bindMemory(to: Double.self, capacity: array.count)
            values.append(contentsOf: UnsafeBufferPointer(start: pointer, count: array.count).map { Float($0) })
        default:
            for index in 0..<array.count {
                values.append(array[index].floatValue)
            }
        }
        var vector = FaceEmbedder.l2Normalize(values)
        if vector.count < AppConstants.embeddingLength {
            vector.append(contentsOf: [Float](repeating: 0, count: AppConstants.embeddingLength - vector.count))
        }
        if vector.count > AppConstants.embeddingLength {
            vector = Array(vector.prefix(AppConstants.embeddingLength))
            vector = FaceEmbedder.l2Normalize(vector)
        }
        return vector
    }

    private func pixelBuffer(from image: CGImage, width: Int, height: Int) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            [kCVPixelBufferCGImageCompatibilityKey: true, kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary,
            &buffer
        )
        guard status == kCVReturnSuccess, let buffer else {
            throw FaceAnalysisError.noEmbedding
        }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            throw FaceAnalysisError.noEmbedding
        }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return buffer
    }
}
