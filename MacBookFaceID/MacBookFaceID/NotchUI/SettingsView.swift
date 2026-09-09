import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var password = ""
    @State private var confirm = ""
    @State private var passwordError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            previewAndEnroll
            toggles
            permissions
            passwordBlock
            footer
        }
        .padding(20)
        .frame(width: 380)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Face Unlock")
                .font(.title3.weight(.semibold))
            Text("Convenience unlock for this Mac — not Secure Enclave Face ID.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var previewAndEnroll: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
                if model.isEnrolling {
                    CameraPreviewView(session: model.camera.session)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    FaceGuideOverlay()
                } else if let image = model.enrollmentPreview {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "camera.viewfinder")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 112, height: 112)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text(model.isEnrolled ? "Face enrolled" : "No face enrolled")
                    .font(.headline)
                Text("Templates are stored only in this Mac’s Application Support folder.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(model.isEnrolled ? "Re-enroll face" : "Enroll face") {
                    Task { await model.enrollFromLiveCamera() }
                }
                .disabled(model.isEnrolling || !model.permissions.cameraGranted)
                if model.isEnrolling {
                    ProgressView(value: model.enrollmentProgress)
                        .progressViewStyle(.linear)
                }
            }
        }
    }

    private var toggles: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Enable Face Unlock", isOn: $model.isEnabled)
            Toggle("Open at login", isOn: $model.opensAtLogin)
            VStack(alignment: .leading, spacing: 6) {
                Text("Animation style")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Animation style", selection: $model.animationStyle) {
                    ForEach(AnimationStyle.allCases) { style in
                        Text("\(style.title) — \(style.subtitle)").tag(style)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }
        }
    }

    private var permissions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Permissions")
                .font(.caption)
                .foregroundStyle(.secondary)
            PermissionRow(
                title: "Camera",
                granted: model.permissions.cameraGranted,
                actionTitle: model.permissions.cameraGranted ? "Allowed" : "Allow"
            ) {
                Task {
                    await model.permissions.requestCamera()
                    if !model.permissions.cameraGranted {
                        model.permissions.openCameraSettings()
                    }
                    model.refreshStatus()
                }
            }
            PermissionRow(
                title: "Accessibility",
                granted: model.permissions.accessibilityTrusted,
                actionTitle: model.permissions.accessibilityTrusted ? "Allowed" : "Open Settings"
            ) {
                model.permissions.promptAccessibility()
                if !model.permissions.accessibilityTrusted {
                    model.permissions.openAccessibilitySettings()
                }
                model.refreshStatus()
            }
            PermissionRow(
                title: "Keychain password",
                granted: model.hasSavedPassword,
                actionTitle: model.hasSavedPassword ? "Saved" : "Needed"
            ) {
                // Focus stays on the fields below.
            }
        }
        .onAppear { model.permissions.refresh() }
    }

    private var passwordBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("macOS login password")
                .font(.caption)
                .foregroundStyle(.secondary)
            SecureField("Password", text: $password)
            SecureField("Confirm", text: $confirm)
            if let passwordError {
                Text(passwordError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            Button(model.hasSavedPassword ? "Update Keychain password" : "Save to Keychain") {
                savePassword()
            }
            .disabled(password.isEmpty)
            Text("Saved in the Keychain (After First Unlock). Never written to a file.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
        HStack {
            Button("Erase enrollment & password", role: .destructive) {
                model.eraseAllData()
                password = ""
                confirm = ""
            }
            Spacer()
            Button("Quit MacBook FaceID") { model.quit() }
        }
        .padding(.top, 4)
    }

    private func savePassword() {
        passwordError = nil
        guard password == confirm else {
            passwordError = "Passwords do not match."
            return
        }
        do {
            try model.savePassword(password)
            password = ""
            confirm = ""
        } catch {
            passwordError = error.localizedDescription
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
