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

struct FaceFrameAnalysis {
    let featurePrint: VNFeaturePrintObservation
    let boundingBox: CGRect
    let quality: Float
}

enum FaceAnalyzer {
    static func analyze(_ image: CGImage, requireQuality: Float? = nil) throws -> FaceFrameAnalysis {
        let detect = VNDetectFaceRectanglesRequest()
        let quality = VNDetectFaceCaptureQualityRequest()
        let printRequest = VNGenerateFaceFeaturePrintRequest()
        printRequest.revision = VNGenerateFaceFeaturePrintRequestRevision1

        let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
        try handler.perform([detect, quality, printRequest])

        let faces = detect.results ?? []
        if faces.isEmpty { throw FaceAnalysisError.noFace }
        if faces.count > 1 { throw FaceAnalysisError.multipleFaces }

        guard let featurePrint = printRequest.results?.first else {
            throw FaceAnalysisError.noFeaturePrint
        }

        let faceQuality = quality.results?.first?.faceCaptureQuality ?? 0
        if let minimum = requireQuality, faceQuality < minimum {
            throw FaceAnalysisError.lowQuality
        }

        return FaceFrameAnalysis(
            featurePrint: featurePrint,
            boundingBox: faces[0].boundingBox,
            quality: faceQuality
        )
    }

    static func distance(
        between lhs: VNFeaturePrintObservation,
        and rhs: VNFeaturePrintObservation
    ) throws -> Float {
        var value: Float = 0
        do {
            try lhs.computeDistance(&value, to: rhs)
        } catch {
            throw FaceAnalysisError.distanceFailed
        }
        return value
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
}
