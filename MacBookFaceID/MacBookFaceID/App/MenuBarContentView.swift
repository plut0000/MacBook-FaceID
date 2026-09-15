import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ScanAnimationView(style: model.animationStyle, phase: displayPhase)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Face Unlock")
                        .font(.headline)
                    Text(model.status.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Toggle("Enable Face Unlock", isOn: $model.isEnabled)
                .onChange(of: model.isEnabled) { _, enabled in
                    model.refreshStatus()
                    if enabled && model.lockObserver.isLocked {
                        model.beginWatching()
                    } else if !enabled {
                        model.stopWatchingIfUnused()
                    }
                }

            HStack {
                Button("Settings") { model.showSettings = true }
                if !model.session.isAuthorized {
                    Button("Authorize") {
                        Task { await model.session.authorize() }
                    }
                }
            }

            Divider()
            Button("Quit") { model.quit() }
        }
        .padding(12)
        .frame(width: 260)
    }

    private var displayPhase: UnlockAnimationPhase {
        if model.animationPhase != .idle { return model.animationPhase }
        return model.status == .watching ? .scanning : .idle
    }
}
