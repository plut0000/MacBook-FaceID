import CoreGraphics
import Foundation
import Vision

/// Nine capture directions used during enrollment. Images are never kept;
/// each accepted frame becomes an embedding and is discarded.
enum HeadPose: String, CaseIterable, Codable, Identifiable {
    case center
    case up
    case down
    case left
    case right
    case upLeft
    case upRight
    case downLeft
    case downRight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .center: return "Look at the camera"
        case .up: return "Tilt your chin up"
        case .down: return "Tilt your chin down"
        case .left: return "Turn a little left"
        case .right: return "Turn a little right"
        case .upLeft: return "Up and left"
        case .upRight: return "Up and right"
        case .downLeft: return "Down and left"
        case .downRight: return "Down and right"
        }
    }

    var hint: String {
        switch self {
        case .center: return "Face the webcam, eyes open, in good light."
        case .up: return "Keep your eyes on the camera while you lift your chin."
        case .down: return "Lower your chin slightly; don’t look at the desk."
        case .left: return "Rotate your head, not just your eyes."
        case .right: return "Rotate your head, not just your eyes."
        case .upLeft, .upRight, .downLeft, .downRight:
            return "A small diagonal turn is enough — don’t go profile."
        }
    }

    /// Approximate yaw/pitch target in normalized face space.
    var target: (yaw: CGFloat, pitch: CGFloat) {
        switch self {
        case .center: return (0, 0)
        case .up: return (0, -0.34)
        case .down: return (0, 0.34)
        case .left: return (-0.38, 0)
        case .right: return (0.38, 0)
        case .upLeft: return (-0.30, -0.28)
        case .upRight: return (0.30, -0.28)
        case .downLeft: return (-0.30, 0.28)
        case .downRight: return (0.30, 0.28)
        }
    }
}

struct PoseEstimate {
    var yaw: CGFloat
    var pitch: CGFloat
    var eyeAspect: CGFloat
    var noseOffset: CGPoint
}

enum PoseEstimator {
    static func estimate(from face: VNFaceObservation) -> PoseEstimate? {
        guard let landmarks = face.landmarks else { return nil }
        let leftEye = centroid(landmarks.leftEye) ?? centroid(landmarks.leftPupil)
        let rightEye = centroid(landmarks.rightEye) ?? centroid(landmarks.rightPupil)
        let nose = centroid(landmarks.noseCrest) ?? centroid(landmarks.nose)
        let mouth = centroid(landmarks.outerLips)
        guard let leftEye, let rightEye, let nose else { return nil }

        let mid = CGPoint(x: (leftEye.x + rightEye.x) / 2, y: (leftEye.y + rightEye.y) / 2)
        let iod = hypot(rightEye.x - leftEye.x, rightEye.y - leftEye.y)
        guard iod > 0.04 else { return nil }

        let yaw = (nose.x - mid.x) / iod
        let mouthY = mouth?.y ?? (mid.y - iod * 1.1)
        let expectedNoseY = (mid.y + mouthY) / 2
        let pitch = (nose.y - expectedNoseY) / iod

        let leftEAR = eyeAspectRatio(landmarks.leftEye)
        let rightEAR = eyeAspectRatio(landmarks.rightEye)
        let ear = ((leftEAR ?? 0.3) + (rightEAR ?? 0.3)) / 2

        return PoseEstimate(
            yaw: yaw,
            pitch: pitch,
            eyeAspect: ear,
            noseOffset: CGPoint(x: (nose.x - mid.x) / iod, y: (nose.y - mid.y) / iod)
        )
    }

    static func matches(_ pose: HeadPose, estimate: PoseEstimate) -> Bool {
        let target = pose.target
        let yawTol: CGFloat = pose == .center ? 0.16 : 0.18
        let pitchTol: CGFloat = pose == .center ? 0.16 : 0.20
        return abs(estimate.yaw - target.yaw) <= yawTol && abs(estimate.pitch - target.pitch) <= pitchTol
    }

    static func centroid(_ region: VNFaceLandmarkRegion2D?) -> CGPoint? {
        guard let region, region.pointCount > 0 else { return nil }
        var x: CGFloat = 0
        var y: CGFloat = 0
        for index in 0..<region.pointCount {
            let point = region.normalizedPoints[index]
            x += point.x
            y += point.y
        }
        let count = CGFloat(region.pointCount)
        return CGPoint(x: x / count, y: y / count)
    }

    static func eyeAspectRatio(_ region: VNFaceLandmarkRegion2D?) -> CGFloat? {
        guard let region, region.pointCount >= 4 else { return nil }
        let points = (0..<region.pointCount).map { region.normalizedPoints[$0] }
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else {
            return nil
        }
        let width = max(maxX - minX, 0.0001)
        let height = max(maxY - minY, 0.0001)
        return height / width
    }
}
