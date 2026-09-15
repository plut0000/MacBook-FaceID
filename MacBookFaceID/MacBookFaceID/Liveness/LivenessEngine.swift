import CoreGraphics
import Foundation

struct LivenessSample {
    let at: Date
    let analysis: FaceFrameAnalysis
}

struct LivenessVerdict: Equatable {
    var passed: Bool
    var reason: String
    var glare: Bool
    var deviceFrame: Bool
    var blink: Bool
    var parallax: Bool
    var geometry: Bool

    static let skipped = LivenessVerdict(
        passed: true,
        reason: "Liveness off",
        glare: false,
        deviceFrame: false,
        blink: false,
        parallax: false,
        geometry: false
    )
}

/// Original spoof checks over a short rolling window.
/// Light: deny cues only (glare, device-shaped rectangle). Missing confirm
/// cues never fail Light, because a still person may not blink.
/// Heavy: deny cues plus at least one confirm cue (blink, nose parallax, 3D-ish geometry).
final class LivenessEngine {
    private var samples: [LivenessSample] = []

    func reset() {
        samples.removeAll()
    }

    func observe(_ analysis: FaceFrameAnalysis, mode: LivenessMode) -> LivenessVerdict {
        if mode == .off { return .skipped }

        let now = Date()
        samples.append(LivenessSample(at: now, analysis: analysis))
        samples.removeAll { now.timeIntervalSince($0.at) > AppConstants.livenessWindow }
        return evaluate(mode: mode)
    }

    private func evaluate(mode: LivenessMode) -> LivenessVerdict {
        let glare = samples.contains { $0.analysis.landmarks.glareRatio > 0.18 }
        let deviceFrame = samples.contains { $0.analysis.landmarks.deviceFrameScore > 0.72 }

        if glare {
            return LivenessVerdict(
                passed: false,
                reason: "Screen glare looks like a photo or a phone.",
                glare: true,
                deviceFrame: deviceFrame,
                blink: false,
                parallax: false,
                geometry: false
            )
        }
        if deviceFrame {
            return LivenessVerdict(
                passed: false,
                reason: "A rectangular frame around the face looks like a device.",
                glare: false,
                deviceFrame: true,
                blink: false,
                parallax: false,
                geometry: false
            )
        }

        if mode == .light {
            return LivenessVerdict(
                passed: true,
                reason: "No spoof deny cues",
                glare: false,
                deviceFrame: false,
                blink: false,
                parallax: false,
                geometry: false
            )
        }

        let blink = detectedBlink()
        let parallax = detectedParallax()
        let geometry = detectedGeometry()
        let confirm = blink || parallax || geometry

        if samples.count < 4 {
            return LivenessVerdict(
                passed: false,
                reason: "Collecting motion…",
                glare: false,
                deviceFrame: false,
                blink: blink,
                parallax: parallax,
                geometry: geometry
            )
        }

        return LivenessVerdict(
            passed: confirm,
            reason: confirm ? "Live motion or geometry" : "No blink, head motion, or 3D geometry yet",
            glare: false,
            deviceFrame: false,
            blink: blink,
            parallax: parallax,
            geometry: geometry
        )
    }

    private func detectedBlink() -> Bool {
        let ears = samples.compactMap { $0.analysis.pose?.eyeAspect }
        guard let maxEAR = ears.max(), let minEAR = ears.min() else { return false }
        return maxEAR > 0.22 && minEAR < 0.14 && (maxEAR - minEAR) > 0.08
    }

    private func detectedParallax() -> Bool {
        let noses = samples.compactMap { $0.analysis.pose?.noseOffset }
        guard noses.count >= 4 else { return false }
        let xs = noses.map(\.x)
        let ys = noses.map(\.y)
        let dx = (xs.max() ?? 0) - (xs.min() ?? 0)
        let dy = (ys.max() ?? 0) - (ys.min() ?? 0)
        return hypot(dx, dy) > 0.08
    }

    private func detectedGeometry() -> Bool {
        // A live face usually has a nose that sits forward of the eye line in
        // normalized landmark space. A flat print often collapses that offset.
        guard let last = samples.last?.analysis.pose else { return false }
        let depth = abs(last.noseOffset.y)
        let spread = abs(last.yaw) + abs(last.pitch)
        return depth > 0.12 && spread < 0.85
    }
}
