import SwiftUI

struct PasswordPane: View {
    @EnvironmentObject private var model: AppModel
    @State private var password = ""
    @State private var confirm = ""
    @State private var errorText: String?

    var body: some View {
        Form {
            if !model.session.isAuthorized {
                Section {
                    Button("Authorize with Touch ID") {
                        Task { await model.session.authorize(prompt: "Show password settings") }
                    }
                } footer: {
                    Text("The login password is encrypted in the local vault. Face Unlock types it only after session, lock screen, match, liveness, and Accessibility all succeed.")
                }
            } else {
                Section {
                    SecureField("macOS login password", text: $password)
                    SecureField("Confirm", text: $confirm)
                    if let errorText {
                        Text(errorText).foregroundStyle(.red)
                    }
                    Button(model.hasSavedPassword ? "Update password" : "Save password") {
                        save()
                    }
                    .disabled(password.isEmpty)
                } footer: {
                    Text(model.hasSavedPassword ? "A password is saved in the vault." : "No password saved yet.")
                }
            }
        }
        .formStyle(.grouped)
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
