import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    @State private var step = 0
    @State private var password = ""
    @State private var confirm = ""
    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("MacBook FaceID")
                .font(.title2.weight(.semibold))
            Text(stepTitle)
                .font(.headline)

            stepBody

            if let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            if let banner = model.bannerMessage, step == 3 {
                Text(banner)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                if step > 0 {
                    Button("Back") { step -= 1 }
                }
                Spacer()
                Button(primaryTitle) { advance() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canAdvance)
            }
        }
        .padding(24)
        .frame(width: 440)
        .onAppear {
            Task { await model.permissions.requestCamera() }
            model.permissions.promptAccessibility()
            model.retainCamera()
        }
        .onDisappear {
            model.releaseCamera()
        }
    }

    private var stepTitle: String {
        switch step {
        case 0: return "Convenience Face Unlock"
        case 1: return "Permissions"
        case 2: return "Save your login password"
        default: return "Enroll your face"
        }
    }

    @ViewBuilder
    private var stepBody: some View {
        switch step {
        case 0:
            VStack(alignment: .leading, spacing: 8) {
                Text("This is not TrueDepth Face ID and it does not use the Secure Enclave. After a local camera match, the app types the password you stored in Keychain.")
                Text("Use it only on a Mac you own. Anyone who looks enough like you — or who can use the camera while you are enrolled — may unlock it.")
                Text("Required later: Camera, Accessibility, and Keychain.")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        case 1:
            VStack(alignment: .leading, spacing: 10) {
                PermissionRow(
                    title: "Camera",
                    granted: model.permissions.cameraGranted,
                    actionTitle: "Allow Camera"
                ) {
                    Task {
                        await model.permissions.requestCamera()
                        if !model.permissions.cameraGranted {
                            model.permissions.openCameraSettings()
                        }
                    }
                }
                PermissionRow(
                    title: "Accessibility",
                    granted: model.permissions.accessibilityTrusted,
                    actionTitle: "Allow Accessibility"
                ) {
                    model.permissions.promptAccessibility()
                    if !model.permissions.accessibilityTrusted {
                        model.permissions.openAccessibilitySettings()
                    }
                }
                Text("Accessibility lets the app type your password into the lock screen. macOS will list MacBook FaceID under Privacy & Security → Accessibility.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case 2:
            VStack(alignment: .leading, spacing: 8) {
                Text("The same password you use at the macOS lock screen. It is stored in Keychain, not in a file.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                SecureField("macOS login password", text: $password)
                SecureField("Confirm password", text: $confirm)
            }
        default:
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    CameraPreviewView(session: model.camera.session)
                    FaceGuideOverlay()
                    if model.isEnrolling {
                        ProgressView(value: model.enrollmentProgress)
                            .progressViewStyle(.linear)
                            .padding()
                            .frame(maxHeight: .infinity, alignment: .bottom)
                    }
                }
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text("Look at the camera in good light. Stay alone in the frame.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var primaryTitle: String {
        switch step {
        case 0: return "Continue"
        case 1: return "Continue"
        case 2: return "Save password"
        default: return model.isEnrolled ? "Done" : "Enroll face"
        }
    }

    private var canAdvance: Bool {
        switch step {
        case 1:
            return model.permissions.cameraGranted && model.permissions.accessibilityTrusted
        case 2:
            return !password.isEmpty && password == confirm
        case 3:
            return !model.isEnrolling
        default:
            return true
        }
    }

    private func advance() {
        errorText = nil
        switch step {
        case 0:
            step = 1
        case 1:
            step = 2
        case 2:
            guard password == confirm else {
                errorText = "Passwords do not match."
                return
            }
            do {
                try model.savePassword(password)
                password = ""
                confirm = ""
                step = 3
            } catch {
                errorText = error.localizedDescription
            }
        default:
            if model.isEnrolled {
                model.completeSetup()
            } else {
                Task { await model.enrollFromLiveCamera() }
            }
        }
    }
}
