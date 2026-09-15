import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    @State private var step = 0
    @State private var password = ""
    @State private var confirm = ""
    @State private var identityName = "You"
    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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

            HStack {
                if step > 0 && step < 4 {
                    Button("Back") { step -= 1 }
                }
                Spacer()
                if step != 4 {
                    Button(primaryTitle) { advance() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(!canAdvance)
                }
            }
        }
        .padding(24)
        .frame(width: 500)
        .onAppear {
            Task { await model.permissions.requestCamera() }
            model.permissions.promptAccessibility()
        }
    }

    private var stepTitle: String {
        switch step {
        case 0: return "Convenience Face Unlock"
        case 1: return "Permissions"
        case 2: return "Authorize this Mac"
        case 3: return "Save your login password"
        default: return "Enroll your face"
        }
    }

    @ViewBuilder
    private var stepBody: some View {
        switch step {
        case 0:
            VStack(alignment: .leading, spacing: 10) {
                Text("This is not TrueDepth Face ID. A Mac webcam sees a flat 2D image; an iPhone Face ID sensor builds a 3D map. Treat this as convenience, not a security upgrade.")
                Text("Unlock works by typing your stored password at the lock screen. There is no macOS API that lets a third-party app authorize a login.")
                Text("Heavy liveness can reject a printed photo or a still image on a phone. It does not reliably defeat a video of you.")
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
                Text("Accessibility is required to type the password into the lock screen. macOS lists this app under Privacy & Security → Accessibility.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case 2:
            VStack(alignment: .leading, spacing: 8) {
                Text("Face data and your password are encrypted with AES-256-GCM. The key lives in Keychain behind Touch ID or your device password, and is held in memory only while a session is authorized.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if model.session.isAuthorized {
                    Label("Session authorized", systemImage: "checkmark.shield.fill")
                        .foregroundStyle(.green)
                } else {
                    Button("Authorize with Touch ID") {
                        Task { await model.session.authorize(prompt: "Create the Face Unlock key") }
                    }
                }
                if let err = model.session.lastError {
                    Text(err).font(.caption).foregroundStyle(.red)
                }
            }
        case 3:
            VStack(alignment: .leading, spacing: 8) {
                Text("The same password you type at the macOS lock screen. It is encrypted in the vault, never stored as plaintext.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                SecureField("macOS login password", text: $password)
                SecureField("Confirm password", text: $confirm)
            }
        default:
            VStack(alignment: .leading, spacing: 10) {
                TextField("Identity name", text: $identityName)
                Text("Turn your head in nine directions. Each frame becomes a 512-number embedding; the image is thrown away.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                EnrollmentView(identityName: identityName) {
                    model.completeSetup()
                }
            }
        }
    }

    private var primaryTitle: String {
        switch step {
        case 0: return "I understand"
        case 1: return "Continue"
        case 2: return "Continue"
        case 3: return "Save password"
        default: return "Done"
        }
    }

    private var canAdvance: Bool {
        switch step {
        case 1:
            return model.permissions.cameraGranted && model.permissions.accessibilityTrusted
        case 2:
            return model.session.isAuthorized
        case 3:
            return !password.isEmpty && password == confirm
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
            step = 3
        case 3:
            guard password == confirm else {
                errorText = "Passwords do not match."
                return
            }
            Task {
                do {
                    try await model.savePassword(password)
                    password = ""
                    confirm = ""
                    step = 4
                } catch {
                    errorText = error.localizedDescription
                }
            }
        default:
            break
        }
    }
}

struct PermissionRow: View {
    let title: String
    let granted: Bool
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(granted ? .green : .secondary)
            Text(title)
            Spacer()
            Button(actionTitle, action: action)
                .disabled(granted)
                .controlSize(.small)
        }
    }
}
