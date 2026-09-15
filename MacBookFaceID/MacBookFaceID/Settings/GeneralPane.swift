import AppKit
import SwiftUI

struct GeneralPane: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("General")
                    .font(.title2.weight(.semibold))

                Toggle("Enable Face Unlock", isOn: $model.isEnabled)
                    .onChange(of: model.isEnabled) { _, enabled in
                        model.refreshStatus()
                        if !enabled { model.stopWatchingIfUnused() }
                    }
                Toggle("Open at login", isOn: $model.opensAtLogin)
                Toggle("Trackpad haptics on hover", isOn: $model.hapticsEnabled)
                Toggle("Hide notch animations", isOn: $model.animationsHidden)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Scan style")
                        .font(.headline)
                    Picker("Scan style", selection: $model.animationStyle) {
                        ForEach(AnimationStyle.allCases) { style in
                            Text("\(style.title) — \(style.subtitle)").tag(style)
                        }
                    }
                    .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Auto-lock session")
                        .font(.headline)
                    Picker("Auto-lock session", selection: $model.sessionIdleLimit) {
                        ForEach(SessionIdleLimit.allCases) { limit in
                            Text(limit.title).tag(limit)
                        }
                    }
                    Text("After this idle time the in-memory key is dropped. Unlock will not type a password until you authorize again.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Text(model.session.isAuthorized ? "Session authorized" : "Session locked")
                            .font(.caption)
                            .foregroundStyle(model.session.isAuthorized ? .green : .secondary)
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
                }

                about
                probe
                danger
            }
        }
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About")
                .font(.headline)
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 48, height: 48)
                    .onTapGesture { model.registerAboutClick() }
                VStack(alignment: .leading, spacing: 2) {
                    Text("MacBook FaceID \(AppConstants.marketingVersion)")
                    Text("Convenience Face Unlock. Not Secure Enclave Face ID.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text("2D webcam ≠ Face ID. A printed photo or phone screen can be rejected with Heavy liveness; a video of you may still succeed. The app types your password via Accessibility because macOS has no third-party login API.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var probe: some View {
        if model.showProbe {
            VStack(alignment: .leading, spacing: 6) {
                Text("Probe")
                    .font(.headline)
                Text(String(format: "Last similarity %.3f  ·  threshold %.2f", model.lastSimilarity, model.matchThreshold))
                    .font(.caption.monospacedDigit())
                Text("Liveness: \(model.lastLiveness.reason)")
                    .font(.caption)
                Text("Engine: \(model.embeddingEngineName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var danger: some View {
        HStack {
            Button("Erase enrollment & password", role: .destructive) {
                model.eraseAllData()
            }
            Spacer()
            Button("Quit MacBook FaceID") { model.quit() }
        }
        .padding(.top, 8)
    }
}
