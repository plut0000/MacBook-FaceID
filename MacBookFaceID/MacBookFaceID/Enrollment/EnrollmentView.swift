import SwiftUI

struct EnrollmentView: View {
    @EnvironmentObject private var model: AppModel
    var identityName: String = "You"
    var onFinished: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.enrollment.currentPose.title)
                .font(.headline)
            Text(model.enrollment.currentPose.hint)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ZStack {
                CameraPreviewView(session: model.camera.session)
                FaceGuideOverlay(
                    pose: model.enrollment.currentPose,
                    lockedIn: model.enrollment.poseLocked,
                    progress: model.enrollment.holdProgress
                )
            }
            .frame(maxWidth: .infinity)
            .frame(height: 248)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )

            HStack(spacing: 10) {
                Text("\(model.enrollment.captured.count) of \(HeadPose.allCases.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                poseTicks
                Spacer(minLength: 0)
                Button("Capture pose") {
                    if let frame = model.camera.latestFrame,
                       let analysis = try? FaceEmbedder.analyze(frame, requireQuality: nil) {
                        model.enrollment.captureNow(analysis)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!model.enrollment.isRunning)
            }

            if let message = model.enrollment.message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            model.retainCamera()
            model.enrollment.start()
            model.camera.onFrame = { image in
                Task { @MainActor in
                    guard model.enrollment.isRunning else { return }
                    if let analysis = try? FaceEmbedder.analyze(image, requireQuality: AppConstants.enrollmentMinQuality) {
                        model.enrollment.consider(analysis)
                    }
                }
            }
            model.camera.start()
        }
        .onDisappear {
            model.enrollment.cancel()
            model.releaseCamera()
            if model.lockObserver.isLocked && model.isEnabled && model.session.isAuthorized {
                model.beginWatching()
            } else if !model.lockObserver.isLocked {
                model.camera.onFrame = nil
            }
        }
        .onChange(of: model.enrollment.isRunning) { _, running in
            if !running && model.enrollment.captured.count == HeadPose.allCases.count {
                save()
            }
        }
    }

    private var poseTicks: some View {
        HStack(spacing: 4) {
            ForEach(HeadPose.allCases) { pose in
                Capsule()
                    .fill(tickColor(for: pose))
                    .frame(width: pose == model.enrollment.currentPose ? 10 : 7, height: 3)
            }
        }
        .accessibilityLabel("Pose \(model.enrollment.captured.count + 1) of \(HeadPose.allCases.count)")
    }

    private func tickColor(for pose: HeadPose) -> Color {
        if model.enrollment.captured[pose] != nil {
            return Color.primary.opacity(0.85)
        }
        if pose == model.enrollment.currentPose {
            return Color.primary.opacity(0.55)
        }
        return Color.primary.opacity(0.18)
    }

    private func save() {
        let identity = model.enrollment.makeIdentity(name: identityName)
        do {
            try model.saveIdentity(identity)
            onFinished()
        } catch {
            model.bannerMessage = error.localizedDescription
        }
    }
}
