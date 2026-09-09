import AppKit
import Vision

enum FaceAnalysisError: LocalizedError {
    case noFace
    case multipleFaces
    case lowQuality
    case noFeaturePrint
    case distanceFailed

    var errorDescription: String? {
        switch self {
        case .noFace:
            return "No face detected. Look at the camera."
        case .multipleFaces:
            return "More than one face is visible. Enroll alone."
        case .lowQuality:
            return "Face capture is too blurry or dark. Move closer and look at the camera."
        case .noFeaturePrint:
            return "Could not build a face template from this frame."
        case .distanceFailed:
            return "Could not compare face templates."
        }
    }
}

/// Similarity-normalized landmark vector. Versioned so a layout change can force re-enroll.
struct FaceEmbedding: Codable, Equatable, Sendable {
    static let currentVersion = 1
    let version: Int
    let values: [Float]
}

struct FaceFrameAnalysis {
    let embedding: FaceEmbedding
    let boundingBox: CGRect
    let quality: Float
}

enum FaceAnalyzer {
    static func analyze(_ image: CGImage, requireQuality: Float? = nil) throws -> FaceFrameAnalysis {
        let landmarksRequest = VNDetectFaceLandmarksRequest()
        let qualityRequest = VNDetectFaceCaptureQualityRequest()

        let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
        try handler.perform([landmarksRequest, qualityRequest])

        let faces = landmarksRequest.results ?? []
        if faces.isEmpty { throw FaceAnalysisError.noFace }
        if faces.count > 1 { throw FaceAnalysisError.multipleFaces }

        let face = faces[0]
        guard let landmarks = face.landmarks else {
            throw FaceAnalysisError.noFeaturePrint
        }
        let embedding = try embed(landmarks)

        let faceQuality = qualityRequest.results?.first?.faceCaptureQuality ?? 0
        if let minimum = requireQuality, faceQuality < minimum {
            throw FaceAnalysisError.lowQuality
        }

        return FaceFrameAnalysis(
            embedding: embedding,
            boundingBox: face.boundingBox,
            quality: faceQuality
        )
    }

    static func distance(between lhs: FaceEmbedding, and rhs: FaceEmbedding) throws -> Float {
        guard lhs.version == rhs.version,
              lhs.values.count == rhs.values.count,
              !lhs.values.isEmpty
        else {
            throw FaceAnalysisError.distanceFailed
        }
        var sum: Float = 0
        for index in lhs.values.indices {
            let delta = lhs.values[index] - rhs.values[index]
            sum += delta * delta
        }
        return sqrt(sum / Float(lhs.values.count))
    }

    static func recordHit(distance: Float, consecutiveHits: inout Int) -> Bool {
        if distance <= AppConstants.tightMatchThreshold {
            consecutiveHits += 2
        } else if distance <= AppConstants.matchThreshold {
            consecutiveHits += 1
        } else {
            consecutiveHits = 0
        }
        return consecutiveHits >= AppConstants.requiredConsecutiveHits
    }

    static func cropFace(from image: CGImage, boundingBox: CGRect) -> NSImage? {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let pad: CGFloat = 0.18
        var rect = CGRect(
            x: boundingBox.minX * width,
            y: (1 - boundingBox.maxY) * height,
            width: boundingBox.width * width,
            height: boundingBox.height * height
        )
        rect = rect.insetBy(dx: -rect.width * pad, dy: -rect.height * pad)
        rect = rect.intersection(CGRect(x: 0, y: 0, width: width, height: height))
        guard !rect.isNull, let cropped = image.cropping(to: rect.integral) else { return nil }
        let size = NSSize(width: cropped.width, height: cropped.height)
        return NSImage(cgImage: cropped, size: size)
    }

    /// Fixed-length embedding: resample each landmark region, then translate / rotate / scale
    /// so the eyes sit on a unit-width horizontal line. That keeps pose and camera distance
    /// from dominating the match.
    private static func embed(_ landmarks: VNFaceLandmarks2D) throws -> FaceEmbedding {
        let regions: [(Int, VNFaceLandmarkRegion2D?)] = [
            (17, landmarks.faceContour),
            (6, landmarks.leftEye),
            (6, landmarks.rightEye),
            (6, landmarks.leftEyebrow),
            (6, landmarks.rightEyebrow),
            (8, landmarks.nose),
            (4, landmarks.noseCrest),
            (10, landmarks.outerLips),
            (6, landmarks.innerLips),
            (1, landmarks.leftPupil),
            (1, landmarks.rightPupil)
        ]

        var collected: [CGPoint] = []
        collected.reserveCapacity(regions.reduce(0) { $0 + $1.0 })
        for (count, region) in regions {
            collected.append(contentsOf: resample(regionPoints(region), count: count))
        }

        let leftEye = centroid(regionPoints(landmarks.leftEye) + regionPoints(landmarks.leftPupil))
        let rightEye = centroid(regionPoints(landmarks.rightEye) + regionPoints(landmarks.rightPupil))
        guard let leftEye, let rightEye else {
            throw FaceAnalysisError.noFeaturePrint
        }

        let mid = CGPoint(x: (leftEye.x + rightEye.x) / 2, y: (leftEye.y + rightEye.y) / 2)
        let dx = rightEye.x - leftEye.x
        let dy = rightEye.y - leftEye.y
        let eyeDistance = hypot(dx, dy)
        guard eyeDistance > 0.05 else {
            throw FaceAnalysisError.noFeaturePrint
        }

        let angle = -atan2(dy, dx)
        let cosA = cos(angle)
        let sinA = sin(angle)
        let scale = 1 / eyeDistance

        var values: [Float] = []
        values.reserveCapacity(collected.count * 2)
        for point in collected {
            let tx = point.x - mid.x
            let ty = point.y - mid.y
            let rx = (tx * cosA - ty * sinA) * scale
            let ry = (tx * sinA + ty * cosA) * scale
            values.append(Float(rx))
            values.append(Float(ry))
        }

        return FaceEmbedding(version: FaceEmbedding.currentVersion, values: values)
    }

    private static func regionPoints(_ region: VNFaceLandmarkRegion2D?) -> [CGPoint] {
        guard let region, region.pointCount > 0 else { return [] }
        return (0..<region.pointCount).map { region.normalizedPoints[$0] }
    }

    private static func centroid(_ points: [CGPoint]) -> CGPoint? {
        guard !points.isEmpty else { return nil }
        let sum = points.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        return CGPoint(x: sum.x / CGFloat(points.count), y: sum.y / CGFloat(points.count))
    }

    private static func resample(_ source: [CGPoint], count: Int) -> [CGPoint] {
        if count <= 0 { return [] }
        if source.isEmpty {
            return Array(repeating: .zero, count: count)
        }
        if source.count == count { return source }
        if count == 1 { return [source[source.count / 2]] }
        if source.count == 1 {
            return Array(repeating: source[0], count: count)
        }

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
}
