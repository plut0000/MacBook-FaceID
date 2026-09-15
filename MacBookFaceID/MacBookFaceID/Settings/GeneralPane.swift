import AppKit
import SwiftUI

struct GeneralPane: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section {
                Toggle("Enable Face Unlock", isOn: $model.isEnabled)
                    .onChange(of: model.isEnabled) { _, enabled in
                        model.refreshStatus()
                        if !enabled { model.stopWatchingIfUnused() }
                    }
                Toggle("Open at login", isOn: $model.opensAtLogin)
            }

            Section("Island") {
                Toggle("Trackpad haptics on hover", isOn: $model.hapticsEnabled)
                Toggle("Hide notch animations", isOn: $model.animationsHidden)
                Picker("Scan style", selection: $model.animationStyle) {
                    ForEach(AnimationStyle.allCases) { style in
                        Text("\(style.title) — \(style.subtitle)").tag(style)
                    }
                }
            }

            Section {
                Picker("Auto-lock", selection: $model.sessionIdleLimit) {
                    ForEach(SessionIdleLimit.allCases) { limit in
                        Text(limit.title).tag(limit)
                    }
                }
                HStack {
                    Text(model.session.isAuthorized ? "Authorized" : "Locked")
                        .foregroundStyle(.secondary)
                    Spacer()
                    if model.session.isAuthorized {
                        Button("Lock now") { model.session.lock() }
                            .controlSize(.small)
                    } else {
                        Button("Authorize") {
                            Task { await model.session.authorize() }
                        }
                        .controlSize(.small)
                    }
                }
            } header: {
                Text("Session")
            } footer: {
                Text("After this idle time the in-memory key is dropped. Unlock will not type a password until you authorize again.")
            }

            Section("About") {
                HStack(alignment: .center, spacing: 12) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 36, height: 36)
                        .onTapGesture { model.registerAboutClick() }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("MacBook FaceID \(AppConstants.marketingVersion)")
                        Text("Convenience unlock. Not Secure Enclave Face ID.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if model.showProbe {
                Section("Probe") {
                    Text(String(format: "Last similarity %.3f  ·  threshold %.2f", model.lastSimilarity, model.matchThreshold))
                        .font(.caption.monospacedDigit())
                    Text("Liveness: \(model.lastLiveness.reason)")
                        .font(.caption)
                    Text("Engine: \(model.embeddingEngineName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button("Erase enrollment & password", role: .destructive) {
                    model.eraseAllData()
                }
                Button("Quit MacBook FaceID") { model.quit() }
            }
        }
        .formStyle(.grouped)
    }
}
