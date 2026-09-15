import SwiftUI

struct FacePane: View {
    @EnvironmentObject private var model: AppModel
    @State private var newName = ""
    @State private var enrolling = false

    var body: some View {
        Group {
            if !model.session.isAuthorized {
                Form {
                    Section {
                        Text("Authorize to view or edit identities.")
                        Button("Authorize with Touch ID") {
                            Task { await model.session.authorize() }
                        }
                    }
                }
                .formStyle(.grouped)
            } else if enrolling {
                EnrollmentView(identityName: newName.isEmpty ? "You" : newName) {
                    enrolling = false
                    newName = ""
                }
                .padding(20)
            } else {
                Form {
                    Section {
                        if model.identities.isEmpty {
                            Text("No identities yet.")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(model.identities) { identity in
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(identity.name)
                                    Text("\(identity.embeddings.count) poses · \(identity.createdAt.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 8)
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
                        }
                    } footer: {
                        Text("Turn one off without deleting it — glasses, a beard, or a different room.")
                    }

                    Section {
                        TextField("Name", text: $newName)
                        Button("Enroll…") {
                            if newName.isEmpty {
                                newName = model.identities.isEmpty ? "You" : "Appearance \(model.identities.count + 1)"
                            }
                            enrolling = true
                        }
                    }
                }
                .formStyle(.grouped)
            }
        }
    }
}
