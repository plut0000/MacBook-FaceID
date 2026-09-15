import SwiftUI

struct PasswordPane: View {
    @EnvironmentObject private var model: AppModel
    @State private var password = ""
    @State private var confirm = ""
    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Password")
                .font(.title2.weight(.semibold))
            Text("Your Mac login password is encrypted in the local vault. The AES key sits in Keychain behind Touch ID. Face Unlock types it only after session + lock screen + match + liveness + Accessibility all succeed.")
                .font(.callout)
                .foregroundStyle(.secondary)

            if !model.session.isAuthorized {
                Button("Authorize with Touch ID") {
                    Task { await model.session.authorize(prompt: "Show password settings") }
                }
            } else {
                SecureField("macOS login password", text: $password)
                SecureField("Confirm", text: $confirm)
                if let errorText {
                    Text(errorText).font(.caption).foregroundStyle(.red)
                }
                Button(model.hasSavedPassword ? "Update password" : "Save password") {
                    save()
                }
                .disabled(password.isEmpty)

                Text(model.hasSavedPassword ? "A password is saved in the vault." : "No password saved yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func save() {
        errorText = nil
        guard password == confirm else {
            errorText = "Passwords do not match."
            return
        }
        Task {
            do {
                try await model.savePassword(password)
                password = ""
                confirm = ""
            } catch {
                errorText = error.localizedDescription
            }
        }
    }
}
