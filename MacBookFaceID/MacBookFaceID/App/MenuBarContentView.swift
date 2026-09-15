import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Face Unlock")
                    .font(.headline)
                Spacer()
                Text(model.status.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle("Enabled", isOn: $model.isEnabled)
                .onChange(of: model.isEnabled) { _, enabled in
                    model.refreshStatus()
                    if enabled && model.lockObserver.isLocked {
                        model.beginWatching()
                    } else if !enabled {
                        model.stopWatchingIfUnused()
                    }
                }

            Divider()

            Button("Settings…") { model.showSettings = true }
            if !model.session.isAuthorized {
                Button("Authorize…") {
                    Task { await model.session.authorize() }
                }
            }

            Divider()
            Button("Quit") { model.quit() }
        }
        .padding(10)
        .frame(width: 228)
    }
}
