import SwiftUI

struct EnrollmentView: View {
    @EnvironmentObject private var model: AppModel
    var identityName: String = "You"
    var onFinished: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(model.enrollment.currentPose.title)
                .font(.title3.weight(.semibold))
            Text(model.enrollment.currentPose.hint)
                .font(.callout)
                .foregroundStyle(.secondary)

            ZStack {
                CameraPreviewView(session: model.camera.session)
                FaceGuideOverlay(
                    pose: model.enrollment.currentPose,
                    lockedIn: model.enrollment.poseLocked
                )
                VStack {
                    Spacer()
                    ProgressView(value: model.enrollment.holdProgress)
                        .progressViewStyle(.linear)
                        .tint(model.enrollment.poseLocked ? .green : .white)
                        .padding(12)
                }
            }
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            HStack {
                Text("\(model.enrollment.captured.count) of \(HeadPose.allCases.count) poses")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                poseDots
            }

            if let message = model.enrollment.message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Capture this pose") {
                    if let frame = model.camera.latestFrame,
                       let analysis = try? FaceEmbedder.analyze(frame, requireQuality: nil) {
                        model.enrollment.captureNow(analysis)
                    }
                }
                .disabled(!model.enrollment.isRunning)
                Spacer()
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

    private var poseDots: some View {
        HStack(spacing: 5) {
            ForEach(HeadPose.allCases) { pose in
                Circle()
                    .fill(model.enrollment.captured[pose] != nil ? Color.green : (pose == model.enrollment.currentPose ? Color.white : Color.secondary.opacity(0.35)))
                    .frame(width: 7, height: 7)
            }
        }
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
