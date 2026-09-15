import Combine
import Foundation

@MainActor
final class EnrollmentSession: ObservableObject {
    @Published var currentPose: HeadPose = .center
    @Published var captured: [HeadPose: FaceEmbedding] = [:]
    @Published var holdProgress: Double = 0
    @Published var message: String?
    @Published var isRunning = false
    @Published var poseLocked = false

    private var holdStarted: Date?
    private var qualityByPose: [HeadPose: Float] = [:]

    var remaining: [HeadPose] {
        HeadPose.allCases.filter { captured[$0] == nil }
    }

    var progress: Double {
        Double(captured.count) / Double(HeadPose.allCases.count)
    }

    func start() {
        captured = [:]
        qualityByPose = [:]
        currentPose = .center
        holdStarted = nil
        holdProgress = 0
        poseLocked = false
        isRunning = true
        message = HeadPose.center.hint
    }

    func cancel() {
        isRunning = false
        holdStarted = nil
    }

    func consider(_ analysis: FaceFrameAnalysis) {
        guard isRunning, captured[currentPose] == nil else { return }
        guard let pose = analysis.pose else {
            message = "Look toward the camera."
            poseLocked = false
            holdStarted = nil
            holdProgress = 0
            return
        }
        let matches = PoseEstimator.matches(currentPose, estimate: pose)
        poseLocked = matches
        if !matches {
            holdStarted = nil
            holdProgress = 0
            message = currentPose.title
            return
        }
        if holdStarted == nil {
            holdStarted = Date()
        }
        let elapsed = Date().timeIntervalSince(holdStarted ?? Date())
        holdProgress = min(1, elapsed / AppConstants.enrollmentPoseHold)
        message = "Hold still…"
        if elapsed >= AppConstants.enrollmentPoseHold {
            captured[currentPose] = analysis.embedding
            qualityByPose[currentPose] = analysis.quality
            holdStarted = nil
            holdProgress = 0
            poseLocked = false
            advance()
        }
    }

    func captureNow(_ analysis: FaceFrameAnalysis) {
        guard isRunning else { return }
        captured[currentPose] = analysis.embedding
        qualityByPose[currentPose] = analysis.quality
        holdStarted = nil
        holdProgress = 0
        advance()
    }

    func makeIdentity(name: String) -> IdentityRecord {
        let poses = HeadPose.allCases.compactMap { pose -> PoseEmbedding? in
            guard let embedding = captured[pose] else { return nil }
            return PoseEmbedding(
                id: UUID(),
                pose: pose,
                embedding: embedding,
                quality: qualityByPose[pose] ?? 0,
                capturedAt: Date()
            )
        }
        return IdentityRecord(
            id: UUID(),
            name: name,
            enabled: true,
            createdAt: Date(),
            embeddings: poses
        )
    }

    private func advance() {
        if let next = remaining.first {
            currentPose = next
            message = next.title
        } else {
            isRunning = false
            message = "All poses captured. Images were discarded."
        }
    }
}
