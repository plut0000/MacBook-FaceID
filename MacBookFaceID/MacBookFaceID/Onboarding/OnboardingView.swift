import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    @State private var step = 0
    @State private var password = ""
    @State private var confirm = ""
    @State private var identityName = "You"
    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(stepTitle)
                .font(.headline)

            stepBody

            if let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Spacer(minLength: 0)

            HStack {
                if step > 0 && step < 4 {
                    Button("Back") { step -= 1 }
                        .keyboardShortcut(.cancelAction)
                }
                Spacer()
                if step != 4 {
                    Button(primaryTitle) { advance() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(!canAdvance)
                }
            }
        }
        .padding(20)
        .frame(width: 440)
        .onAppear {
            Task { await model.permissions.requestCamera() }
            model.permissions.promptAccessibility()
        }
    }

    private var stepTitle: String {
        switch step {
        case 0: return "Read this first"
        case 1: return "Permissions"
        case 2: return "Authorize"
        case 3: return "Login password"
        default: return "Enroll"
        }
    }

    @ViewBuilder
    private var stepBody: some View {
        switch step {
        case 0:
            VStack(alignment: .leading, spacing: 8) {
                Text("This Mac has a 2D camera, not Face ID. Unlock types your saved password at the lock screen.")
                Text("Heavy liveness can reject a printed photo. A video of you may still succeed.")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        case 1:
            VStack(alignment: .leading, spacing: 8) {
                PermissionRow(
                    title: "Camera",
                    granted: model.permissions.cameraGranted,
                    actionTitle: "Allow"
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
                    actionTitle: "Allow"
                ) {
                    model.permissions.promptAccessibility()
                    if !model.permissions.accessibilityTrusted {
                        model.permissions.openAccessibilitySettings()
                    }
                }
                Text("Accessibility types the password into the lock screen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case 2:
            VStack(alignment: .leading, spacing: 8) {
                Text("Face data and your password are encrypted. The key stays in Keychain behind Touch ID.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if model.session.isAuthorized {
                    Label("Authorized", systemImage: "checkmark")
                        .foregroundStyle(.secondary)
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
                Text("The password you type at the macOS lock screen. Stored encrypted, never as plaintext.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                SecureField("macOS login password", text: $password)
                SecureField("Confirm", text: $confirm)
            }
        default:
            VStack(alignment: .leading, spacing: 10) {
                TextField("Identity name", text: $identityName)
                Text("Nine head poses. Each frame becomes numbers; the image is discarded.")
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
        case 0: return "Continue"
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
                .foregroundStyle(granted ? .secondary : .tertiary)
                .symbolRenderingMode(.hierarchical)
            Text(title)
            Spacer()
            Button(actionTitle, action: action)
                .disabled(granted)
                .controlSize(.small)
        }
    }
}
