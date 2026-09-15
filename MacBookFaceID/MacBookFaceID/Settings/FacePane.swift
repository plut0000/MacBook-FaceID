import SwiftUI

struct FacePane: View {
    @EnvironmentObject private var model: AppModel
    @State private var newName = ""
    @State private var enrolling = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Face")
                .font(.title2.weight(.semibold))
            Text("Each identity is a set of pose embeddings. Toggle one off without deleting it — useful for glasses, a beard, or a different lighting setup.")
                .font(.callout)
                .foregroundStyle(.secondary)

            if !model.session.isAuthorized {
                sessionPrompt
            } else if enrolling {
                EnrollmentView(identityName: newName.isEmpty ? "You" : newName) {
                    enrolling = false
                    newName = ""
                }
            } else {
                identityList
                HStack {
                    TextField("New identity name", text: $newName)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 220)
                    Button("Enroll another") {
                        if newName.isEmpty { newName = model.identities.isEmpty ? "You" : "Appearance \(model.identities.count + 1)" }
                        enrolling = true
                    }
                }
            }
        }
    }

    private var sessionPrompt: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Authorize to view or edit identities.")
            Button("Authorize with Touch ID") {
                Task { await model.session.authorize() }
            }
        }
    }

    private var identityList: some View {
        VStack(alignment: .leading, spacing: 8) {
            if model.identities.isEmpty {
                Text("No identities yet. Enroll your face to start.")
                    .foregroundStyle(.secondary)
            }
            ForEach(model.identities) { identity in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(identity.name)
                            .font(.headline)
                        Text("\(identity.embeddings.count) poses · \(identity.createdAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("Enabled", isOn: Binding(
                        get: { identity.enabled },
                        set: { model.setIdentityEnabled(identity, enabled: $0) }
                    ))
                    .labelsHidden()
                    Button("Delete", role: .destructive) {
                        model.deleteIdentity(identity)
                    }
                    .controlSize(.small)
                }
                .padding(10)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }
}
